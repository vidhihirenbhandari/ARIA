from __future__ import annotations

import hashlib
import hmac
import logging
from typing import Any, Dict, Optional

from fastapi import APIRouter, BackgroundTasks, Header, HTTPException, Query, Request, status
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel

from app.core.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks", tags=["Webhooks"])

# Keywords that suggest an email is travel-related
_TRAVEL_KEYWORDS = frozenset(
    [
        "flight",
        "hotel",
        "booking",
        "confirmation",
        "reservation",
        "itinerary",
        "airline",
        "check-in",
        "check in",
        "boarding",
        "departure",
        "arrival",
        "ticket",
        "train",
        "car rental",
        "rental car",
    ]
)

# Keywords that suggest an email is meeting/event-related
_MEETING_KEYWORDS = frozenset(
    [
        "meeting",
        "invite",
        "invitation",
        "calendar",
        "zoom",
        "teams",
        "google meet",
        "conference",
        "agenda",
        "schedule",
        "appointment",
    ]
)


# ── Helpers ────────────────────────────────────────────────────────────────────


def _verify_whatsapp_signature(payload: bytes, signature_header: Optional[str]) -> bool:
    """Verify X-Hub-Signature-256 from WhatsApp Cloud API."""
    if not settings.WHATSAPP_APP_SECRET:
        # If no secret is configured, skip verification (dev mode)
        logger.warning("WHATSAPP_APP_SECRET not set; skipping signature verification")
        return True
    if not signature_header:
        return False
    expected_prefix = "sha256="
    if not signature_header.startswith(expected_prefix):
        return False
    received_hash = signature_header[len(expected_prefix):]
    computed = hmac.new(
        settings.WHATSAPP_APP_SECRET.encode(),
        payload,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(computed, received_hash)


def _is_travel_email(subject: str, body: str) -> bool:
    combined = (subject + " " + body).lower()
    return any(kw in combined for kw in _TRAVEL_KEYWORDS)


def _is_meeting_email(subject: str, body: str) -> bool:
    combined = (subject + " " + body).lower()
    return any(kw in combined for kw in _MEETING_KEYWORDS)


def _find_user_by_whatsapp_number(phone: str):
    """
    Placeholder: look up a user by their WhatsApp phone number.
    In a real system this would query the DB for a matching integration record.
    Returns user_id (str) or None.
    """
    return None


# ── WhatsApp webhook verification (GET) ───────────────────────────────────────


@router.get(
    "/whatsapp/verify",
    response_class=PlainTextResponse,
    summary="WhatsApp webhook verification challenge",
)
async def whatsapp_verify(
    hub_mode: Optional[str] = Query(None, alias="hub.mode"),
    hub_verify_token: Optional[str] = Query(None, alias="hub.verify_token"),
    hub_challenge: Optional[str] = Query(None, alias="hub.challenge"),
) -> str:
    """
    WhatsApp Cloud API calls this endpoint with a GET request to verify the webhook URL.
    We must echo back hub.challenge if hub.verify_token matches our configured token.
    """
    if hub_mode != "subscribe":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid hub.mode",
        )
    if hub_verify_token != settings.WHATSAPP_VERIFY_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Verification token mismatch",
        )
    if not hub_challenge:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="hub.challenge missing",
        )
    return hub_challenge


# ── WhatsApp message ingestion (POST) ─────────────────────────────────────────


@router.post(
    "/whatsapp",
    status_code=status.HTTP_200_OK,
    summary="Ingest incoming WhatsApp messages and trigger AI event detection",
)
async def whatsapp_webhook(
    request: Request,
    background_tasks: BackgroundTasks,
    x_hub_signature_256: Optional[str] = Header(None, alias="X-Hub-Signature-256"),
):
    """
    Receives incoming messages from WhatsApp Cloud API.
    Verifies the HMAC-SHA256 signature, extracts message text, and fires a
    Celery task to detect meetings/events in the message.

    WhatsApp requires a 200 OK response within ~5 seconds, so all heavy
    processing is deferred to a background Celery task.
    """
    raw_body = await request.body()

    if not _verify_whatsapp_signature(raw_body, x_hub_signature_256):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid WhatsApp signature",
        )

    try:
        payload: Dict[str, Any] = await request.json()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid JSON payload",
        )

    # Walk the WhatsApp Cloud API payload structure
    # payload.entry[].changes[].value.messages[]
    entries = payload.get("entry", [])
    for entry in entries:
        for change in entry.get("changes", []):
            value = change.get("value", {})
            messages = value.get("messages", [])
            for msg in messages:
                msg_type = msg.get("type", "")
                if msg_type != "text":
                    continue  # Only handle text messages

                message_text: str = msg.get("text", {}).get("body", "").strip()
                sender_phone: str = msg.get("from", "")

                if not message_text:
                    continue

                logger.info(
                    "WhatsApp message received from %s: %.80s...",
                    sender_phone,
                    message_text,
                )

                # Attempt to resolve a user by phone number
                user_id = _find_user_by_whatsapp_number(sender_phone)

                def _fire_task(uid: Optional[str], text: str):
                    try:
                        from app.workers.tasks import process_message_for_events
                        if uid:
                            process_message_for_events.delay(uid, text, "whatsapp")
                        else:
                            logger.info(
                                "No ARIA user found for WhatsApp number %s; message logged only",
                                sender_phone,
                            )
                    except Exception as exc:
                        logger.error("Failed to queue whatsapp task: %s", exc)

                background_tasks.add_task(_fire_task, user_id, message_text)

    # WhatsApp requires a fast 200 OK — always return immediately
    return {"status": "ok"}


# ── Email webhook (POST) ───────────────────────────────────────────────────────


class EmailWebhookPayload(BaseModel):
    """
    Generic email webhook payload compatible with Mailgun/SendGrid forwarding.
    All fields are optional to maximise compatibility.
    """
    sender: Optional[str] = None
    recipient: Optional[str] = None
    subject: Optional[str] = ""
    body_plain: Optional[str] = ""
    body_html: Optional[str] = ""
    # Some providers send these as top-level fields
    from_: Optional[str] = None
    to: Optional[str] = None
    text: Optional[str] = None
    html: Optional[str] = None
    # User identification (can be set by the forwarding service via custom fields)
    user_id: Optional[str] = None


@router.post(
    "/email",
    status_code=status.HTTP_200_OK,
    summary="Receive forwarded email content and trigger AI processing",
)
async def email_webhook(
    payload: EmailWebhookPayload,
    background_tasks: BackgroundTasks,
):
    """
    Receives a forwarded email from a service like Mailgun or SendGrid.
    Checks whether the email is travel- or meeting-related and fires the
    appropriate Celery task. Returns 200 OK immediately.
    """
    subject = payload.subject or ""
    body = payload.body_plain or payload.text or ""

    if not body:
        # Fall back to HTML body if plain text is unavailable
        body = payload.body_html or payload.html or ""

    user_id = payload.user_id  # May be None if not provided by forwarding service

    if not body and not subject:
        logger.warning("Email webhook received with empty body and subject; ignoring")
        return {"status": "ignored", "reason": "empty content"}

    is_travel = _is_travel_email(subject, body)
    is_meeting = _is_meeting_email(subject, body)

    logger.info(
        "Email webhook: subject=%r travel=%s meeting=%s user_id=%s",
        subject[:60],
        is_travel,
        is_meeting,
        user_id,
    )

    if is_travel and user_id:
        def _fire_travel(uid: str, b: str, s: str):
            try:
                from app.workers.tasks import detect_travel_from_email_task
                detect_travel_from_email_task.delay(uid, b, s)
            except Exception as exc:
                logger.error("Failed to queue travel email task: %s", exc)

        background_tasks.add_task(_fire_travel, user_id, body, subject)
        return {"status": "ok", "action": "travel_detection_queued"}

    if is_meeting and user_id:
        def _fire_meeting(uid: str, b: str):
            try:
                from app.workers.tasks import process_message_for_events
                process_message_for_events.delay(uid, b, "email")
            except Exception as exc:
                logger.error("Failed to queue meeting email task: %s", exc)

        background_tasks.add_task(_fire_meeting, user_id, body)
        return {"status": "ok", "action": "event_detection_queued"}

    if not user_id:
        logger.info("Email webhook: no user_id provided; content logged only")
        return {"status": "ok", "action": "logged_no_user"}

    return {"status": "ok", "action": "no_matching_pattern"}


# ── WhatsApp POST verify (alias) ───────────────────────────────────────────────


@router.post(
    "/whatsapp/verify",
    response_class=PlainTextResponse,
    summary="WhatsApp webhook verification (POST fallback)",
)
async def whatsapp_verify_post(
    hub_mode: Optional[str] = Query(None, alias="hub.mode"),
    hub_verify_token: Optional[str] = Query(None, alias="hub.verify_token"),
    hub_challenge: Optional[str] = Query(None, alias="hub.challenge"),
) -> str:
    """POST variant of the WhatsApp verification challenge (delegates to GET handler)."""
    return await whatsapp_verify(hub_mode, hub_verify_token, hub_challenge)
