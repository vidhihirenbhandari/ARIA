from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.common import SuccessResponse
from app.services.notification_service import notification_service

router = APIRouter(prefix="/notifications", tags=["Notifications"])


class NotificationSettings(BaseModel):
    push_enabled: bool = True
    event_reminders: bool = True
    task_reminders: bool = True
    daily_briefing: bool = True
    travel_alerts: bool = True
    reminder_minutes_before: int = 15


class DeviceRegistration(BaseModel):
    fcm_token: str
    platform: Optional[str] = None  # ios / android / web


class TestNotificationRequest(BaseModel):
    title: str = "ARIA Test"
    body: str = "This is a test notification from ARIA."


@router.get("/settings", response_model=NotificationSettings, summary="Get notification settings")
async def get_settings(
    current_user: User = Depends(get_current_user),
) -> NotificationSettings:
    # In production, persist these in a NotificationSettings DB table.
    # For now, return defaults.
    return NotificationSettings()


@router.put("/settings", response_model=NotificationSettings, summary="Update notification settings")
async def update_settings(
    body: NotificationSettings,
    current_user: User = Depends(get_current_user),
) -> NotificationSettings:
    # Persist logic would go here.
    return body


@router.post("/register-device", response_model=SuccessResponse, summary="Register FCM device token")
async def register_device(
    body: DeviceRegistration,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SuccessResponse:
    current_user.fcm_token = body.fcm_token
    await db.commit()
    return SuccessResponse(message="Device registered successfully")


@router.post("/test", response_model=SuccessResponse, summary="Send a test push notification")
async def send_test_notification(
    body: TestNotificationRequest,
    current_user: User = Depends(get_current_user),
) -> SuccessResponse:
    if not current_user.fcm_token:
        raise HTTPException(
            status_code=400,
            detail="No FCM token registered. Call /notifications/register-device first.",
        )
    sent = await notification_service.send_push_notification(
        fcm_token=current_user.fcm_token,
        title=body.title,
        body=body.body,
    )
    if not sent:
        raise HTTPException(status_code=503, detail="Failed to send notification")
    return SuccessResponse(message="Test notification sent")
