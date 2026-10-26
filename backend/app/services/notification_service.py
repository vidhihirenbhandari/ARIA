from __future__ import annotations

import json
import logging
from typing import Any, Dict, Optional

logger = logging.getLogger(__name__)

_firebase_initialized = False


def _init_firebase() -> bool:
    """Lazy-initialize Firebase Admin SDK."""
    global _firebase_initialized
    if _firebase_initialized:
        return True
    from app.core.config import settings

    if not settings.FIREBASE_CREDENTIALS:
        logger.warning("FIREBASE_CREDENTIALS not set; push notifications disabled")
        return False
    try:
        import firebase_admin
        from firebase_admin import credentials

        cred_dict = json.loads(settings.FIREBASE_CREDENTIALS)
        cred = credentials.Certificate(cred_dict)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        return True
    except Exception as exc:
        logger.error("Firebase init failed: %s", exc)
        return False


class NotificationService:
    """Firebase Cloud Messaging push notifications."""

    async def send_push_notification(
        self,
        fcm_token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None,
    ) -> bool:
        """Send a push notification to a device."""
        if not _init_firebase():
            return False
        if not fcm_token:
            logger.warning("No FCM token provided")
            return False
        try:
            from firebase_admin import messaging

            message = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                data=data or {},
                token=fcm_token,
            )
            response = messaging.send(message)
            logger.info("Sent FCM notification: %s", response)
            return True
        except Exception as exc:
            logger.error("Failed to send push notification: %s", exc)
            return False

    async def send_to_user(
        self,
        user,  # User ORM object
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None,
    ) -> bool:
        """Convenience: send notification to a user by their stored FCM token."""
        if not user.fcm_token:
            return False
        return await self.send_push_notification(user.fcm_token, title, body, data)

    async def schedule_event_reminder(
        self, event: Any, fcm_token: str, minutes_before: int = 15
    ) -> None:
        """
        In a real system this would enqueue a Celery task delayed by
        (event.start_time - minutes_before). Here we log the intent.
        """
        logger.info(
            "Would schedule reminder for event '%s' %d minutes before start to token %s",
            getattr(event, "title", str(event)),
            minutes_before,
            fcm_token[:10] + "..." if fcm_token else "none",
        )


notification_service = NotificationService()
