from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)

# ── Helpers ────────────────────────────────────────────────────────────────────


def _run(coro):
    """Run an async coroutine from a sync Celery task."""
    return asyncio.run(coro)


# ── Tasks ──────────────────────────────────────────────────────────────────────


@celery_app.task(name="app.workers.tasks.send_daily_briefings", bind=True, max_retries=3)
def send_daily_briefings(self):
    """
    Scheduled task (7 AM UTC daily).
    Queries all active users, generates a daily briefing for each,
    and sends an FCM push notification.
    """

    async def _run_async():
        from sqlalchemy import select

        from app.core.database import async_session_factory
        from app.models.event import Event
        from app.models.task import Task
        from app.models.travel import Travel
        from app.models.user import User
        from app.services.ai_service import ai_service
        from app.services.notification_service import notification_service

        now = datetime.now(timezone.utc)
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        today_end = today_start + timedelta(days=1)

        async with async_session_factory() as db:
            # Fetch all active users with an FCM token
            result = await db.execute(
                select(User).where(User.is_active == True)  # noqa: E712
            )
            users = result.scalars().all()

        for user in users:
            try:
                async with async_session_factory() as db:
                    # Today's events
                    events_result = await db.execute(
                        select(Event).where(
                            Event.user_id == user.id,
                            Event.status.in_(["approved", "synced"]),
                            Event.start_time >= today_start,
                            Event.start_time < today_end,
                        )
                    )
                    events = [
                        {
                            "title": e.title,
                            "start_time": e.start_time.isoformat() if e.start_time else None,
                            "end_time": e.end_time.isoformat() if e.end_time else None,
                            "location": e.location,
                        }
                        for e in events_result.scalars().all()
                    ]

                    # Pending tasks
                    tasks_result = await db.execute(
                        select(Task).where(
                            Task.user_id == user.id,
                            Task.status.in_(["pending", "in_progress"]),
                        )
                    )
                    tasks = [
                        {
                            "title": t.title,
                            "priority": t.priority,
                            "due_date": t.due_date.isoformat() if t.due_date else None,
                        }
                        for t in tasks_result.scalars().all()
                    ]

                    # Upcoming travel
                    travel_result = await db.execute(
                        select(Travel).where(
                            Travel.user_id == user.id,
                            Travel.status == "upcoming",
                            Travel.departure_time >= now,
                        )
                    )
                    travel = [
                        {
                            "type": tr.travel_type,
                            "departure": tr.departure_time.isoformat() if tr.departure_time else None,
                            "details": tr.details,
                        }
                        for tr in travel_result.scalars().all()
                    ]

                    # Pending suggestions (pending events)
                    pending_result = await db.execute(
                        select(Event).where(
                            Event.user_id == user.id,
                            Event.status == "pending",
                        )
                    )
                    pending_suggestions = [
                        {
                            "id": str(e.id),
                            "title": e.title,
                            "start_time": e.start_time.isoformat() if e.start_time else None,
                        }
                        for e in pending_result.scalars().all()
                    ]

                briefing = await ai_service.generate_daily_briefing(
                    events=events,
                    tasks=tasks,
                    travel=travel,
                )

                # Send FCM push notification if user has a token
                if user.fcm_token:
                    await notification_service.send_push_notification(
                        fcm_token=user.fcm_token,
                        title=f"Good morning! {briefing.greeting[:60]}",
                        body=briefing.ai_summary[:200] if briefing.ai_summary else "Here's your daily briefing.",
                        data={
                            "type": "daily_briefing",
                            "events_count": str(len(events)),
                            "tasks_count": str(len(tasks)),
                            "pending_count": str(len(pending_suggestions)),
                        },
                    )
                    logger.info("Sent daily briefing to user %s", user.id)
                else:
                    logger.debug("User %s has no FCM token; skipping push", user.id)

            except Exception as exc:
                logger.error("Failed to send briefing to user %s: %s", user.id, exc)

    try:
        _run(_run_async())
    except Exception as exc:
        logger.error("send_daily_briefings task failed: %s", exc)
        raise self.retry(exc=exc, countdown=60)


@celery_app.task(
    name="app.workers.tasks.process_message_for_events",
    bind=True,
    max_retries=3,
)
def process_message_for_events(self, user_id: str, message_text: str, source: str = "whatsapp"):
    """
    Detect meeting/event intent in a message and create a pending Event record.
    Fires an FCM push notification when a meeting is detected.

    Returns the created event id (str) or None.
    """

    async def _run_async():
        from app.core.database import async_session_factory
        from app.models.event import Event
        from app.models.user import User
        from app.services.ai_service import ai_service
        from app.services.notification_service import notification_service
        from app.utils.helpers import parse_datetime
        from sqlalchemy import select

        # Detect intent
        intent = await ai_service.detect_intent(message_text)

        if intent.intent_type not in ("meeting", "task") or intent.confidence < 0.6:
            logger.debug(
                "Message from user %s classified as '%s' (conf=%.2f); skipping event creation",
                user_id,
                intent.intent_type,
                intent.confidence,
            )
            return None

        # Extract structured events
        raw_events = await ai_service.extract_event_from_text(message_text)
        if not raw_events:
            logger.debug("No structured events extracted for user %s", user_id)
            return None

        created_ids = []

        async with async_session_factory() as db:
            user_result = await db.execute(
                select(User).where(User.id == uuid.UUID(user_id))
            )
            user = user_result.scalar_one_or_none()

            for item in raw_events:
                start = parse_datetime(item.get("start_time") or "")
                end = parse_datetime(item.get("end_time") or "")
                confidence = float(item.get("confidence", intent.confidence))

                if not start:
                    continue

                event = Event(
                    user_id=uuid.UUID(user_id),
                    title=item.get("title", "Untitled Meeting"),
                    start_time=start,
                    end_time=end,
                    location=item.get("location"),
                    attendees=item.get("attendees", []),
                    source=source,
                    confidence_score=confidence,
                    status="pending",
                    raw_text=message_text,
                )
                db.add(event)
                await db.flush()  # get the id before commit
                created_ids.append(str(event.id))

                # Send FCM push notification
                if user and user.fcm_token:
                    await notification_service.send_push_notification(
                        fcm_token=user.fcm_token,
                        title="Meeting detected",
                        body=f"{item.get('title', 'Meeting')} — {start.strftime('%b %d %H:%M') if start else 'time TBD'}",
                        data={
                            "type": "event_detected",
                            "event_id": str(event.id),
                            "source": source,
                        },
                    )

            await db.commit()

        return created_ids[0] if created_ids else None

    try:
        return _run(_run_async())
    except Exception as exc:
        logger.error("process_message_for_events failed for user %s: %s", user_id, exc)
        raise self.retry(exc=exc, countdown=30)


@celery_app.task(
    name="app.workers.tasks.detect_travel_from_email_task",
    bind=True,
    max_retries=3,
)
def detect_travel_from_email_task(self, user_id: str, email_body: str, email_subject: str = ""):
    """
    Detect travel bookings from a forwarded email body, create TravelBooking records,
    and fire FCM push notifications with contextual suggestions.

    Returns the first created booking id (str) or None.
    """

    async def _run_async():
        from app.core.database import async_session_factory
        from app.models.travel import Travel
        from app.models.user import User
        from app.services.notification_service import notification_service
        from app.services.travel_service import travel_service
        from app.utils.helpers import parse_datetime
        from sqlalchemy import select

        bookings = await travel_service.detect_travel_from_email(email_body)
        if not bookings:
            logger.debug("No travel detected in email for user %s (subject: %r)", user_id, email_subject)
            return None

        created_ids = []

        async with async_session_factory() as db:
            user_result = await db.execute(
                select(User).where(User.id == uuid.UUID(user_id))
            )
            user = user_result.scalar_one_or_none()

            for item in bookings:
                travel = Travel(
                    user_id=uuid.UUID(user_id),
                    travel_type=item.get("travel_type", "flight"),
                    details=item.get("details", {}),
                    departure_time=parse_datetime(item.get("departure_time") or ""),
                    arrival_time=parse_datetime(item.get("arrival_time") or ""),
                    source="email",
                    status="upcoming",
                )
                db.add(travel)
                await db.flush()
                created_ids.append(str(travel.id))

                # Generate contextual suggestions and push
                if user and user.fcm_token:
                    details = item.get("details", {})
                    travel_type = item.get("travel_type", "flight")

                    # Build a helpful suggestions body
                    suggestions = []
                    if travel_type == "flight":
                        suggestions.append("Set check-in alarm 3h before departure")
                        suggestions.append("Book airport cab")
                        suggestions.append("Check weather at destination")
                        suggestions.append("Review packing checklist")
                    elif travel_type == "hotel":
                        suggestions.append("Confirm check-in details")
                        suggestions.append("Book airport transfer")
                    else:
                        suggestions.append("Review booking details")

                    from_loc = details.get("from") or details.get("hotel_name", "")
                    body = f"Travel detected: {travel_type}"
                    if from_loc:
                        body += f" — {from_loc}"
                    body += f". Suggestions: {'; '.join(suggestions[:2])}"

                    await notification_service.send_push_notification(
                        fcm_token=user.fcm_token,
                        title="Travel booking detected",
                        body=body[:200],
                        data={
                            "type": "travel_detected",
                            "travel_id": str(travel.id),
                            "travel_type": travel_type,
                            "suggestions": ",".join(suggestions),
                        },
                    )

            await db.commit()

        return created_ids[0] if created_ids else None

    try:
        return _run(_run_async())
    except Exception as exc:
        logger.error("detect_travel_from_email_task failed for user %s: %s", user_id, exc)
        raise self.retry(exc=exc, countdown=30)


@celery_app.task(name="app.workers.tasks.cleanup_old_rejected_events", bind=True, max_retries=2)
def cleanup_old_rejected_events(self):
    """
    Scheduled task (2 AM UTC daily).
    Deletes rejected events older than 7 days.
    """

    async def _run_async():
        from sqlalchemy import delete

        from app.core.database import async_session_factory
        from app.models.event import Event

        cutoff = datetime.now(timezone.utc) - timedelta(days=7)

        async with async_session_factory() as db:
            result = await db.execute(
                delete(Event).where(
                    Event.status == "rejected",
                    Event.updated_at < cutoff,
                )
            )
            await db.commit()
            deleted = result.rowcount
            logger.info("Cleaned up %d rejected events older than 7 days", deleted)
            return deleted

    try:
        return _run(_run_async())
    except Exception as exc:
        logger.error("cleanup_old_rejected_events failed: %s", exc)
        raise self.retry(exc=exc, countdown=120)
