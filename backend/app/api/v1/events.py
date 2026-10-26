from __future__ import annotations

import uuid
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.event import Event
from app.models.user import User
from app.schemas.common import PaginatedResponse, SuccessResponse
from app.schemas.event import (
    EventApproveRequest,
    EventCreate,
    EventDetectRequest,
    EventDetectResponse,
    EventResponse,
    EventUpdate,
    DetectedEvent,
)
from app.services.ai_service import ai_service
from app.utils.helpers import parse_datetime

router = APIRouter(prefix="/events", tags=["Events"])


@router.get(
    "",
    response_model=PaginatedResponse[EventResponse],
    summary="List events",
)
async def list_events(
    status_filter: Optional[str] = Query(None, alias="status"),
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PaginatedResponse[EventResponse]:
    q = select(Event).where(Event.user_id == current_user.id)
    if status_filter:
        q = q.where(Event.status == status_filter)
    if start_date:
        q = q.where(Event.start_time >= start_date)
    if end_date:
        q = q.where(Event.start_time <= end_date)

    count_q = q
    total = len((await db.execute(count_q)).scalars().all())

    q = q.order_by(Event.start_time.asc()).offset((page - 1) * page_size).limit(page_size)
    rows = (await db.execute(q)).scalars().all()

    return PaginatedResponse(
        items=[EventResponse.model_validate(r) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
        has_next=(page * page_size) < total,
    )


@router.post(
    "",
    response_model=EventResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create event manually",
)
async def create_event(
    body: EventCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> EventResponse:
    event = Event(
        user_id=current_user.id,
        **body.model_dump(),
        status="approved",
    )
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return EventResponse.model_validate(event)


@router.post(
    "/detect",
    response_model=EventDetectResponse,
    summary="Detect events from natural language text",
)
async def detect_events(
    body: EventDetectRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> EventDetectResponse:
    raw_events = await ai_service.extract_event_from_text(body.text)

    detected: list[DetectedEvent] = []
    saved_events: list[Event] = []

    for item in raw_events:
        start = parse_datetime(item.get("start_time") or "")
        end = parse_datetime(item.get("end_time") or "")
        confidence = float(item.get("confidence", 0.7))

        detected.append(
            DetectedEvent(
                title=item.get("title", "Untitled"),
                start_time=start,
                end_time=end,
                location=item.get("location"),
                attendees=item.get("attendees", []),
                confidence_score=confidence,
                raw_text=item.get("raw_text", body.text),
            )
        )

        # Persist as pending events for user review
        if start:
            event = Event(
                user_id=current_user.id,
                title=item.get("title", "Untitled"),
                start_time=start,
                end_time=end,
                location=item.get("location"),
                attendees=item.get("attendees", []),
                source="ai_detected",
                confidence_score=confidence,
                status="pending",
                raw_text=body.text,
            )
            db.add(event)
            saved_events.append(event)

    if saved_events:
        await db.commit()

    overall = sum(e.confidence_score for e in detected) / len(detected) if detected else 0.0
    return EventDetectResponse(events=detected, overall_confidence=round(overall, 4))


@router.get(
    "/{event_id}",
    response_model=EventResponse,
    summary="Get event by ID",
)
async def get_event(
    event_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> EventResponse:
    event = await _get_user_event(db, event_id, current_user.id)
    return EventResponse.model_validate(event)


@router.put(
    "/{event_id}",
    response_model=EventResponse,
    summary="Update event",
)
async def update_event(
    event_id: uuid.UUID,
    body: EventUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> EventResponse:
    event = await _get_user_event(db, event_id, current_user.id)
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(event, field, value)
    await db.commit()
    await db.refresh(event)
    return EventResponse.model_validate(event)


@router.delete(
    "/{event_id}",
    response_model=SuccessResponse,
    summary="Delete event",
)
async def delete_event(
    event_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SuccessResponse:
    event = await _get_user_event(db, event_id, current_user.id)
    await db.delete(event)
    await db.commit()
    return SuccessResponse(message="Event deleted")


@router.post(
    "/{event_id}/approve",
    response_model=EventResponse,
    summary="Approve a suggested event",
)
async def approve_event(
    event_id: uuid.UUID,
    body: EventApproveRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> EventResponse:
    event = await _get_user_event(db, event_id, current_user.id)
    event.status = "approved"

    if body.sync_to_calendar and body.calendar_service:
        # Attempt to sync to the configured calendar
        from app.services.calendar_service import calendar_service
        from app.services.integration_service import integration_service

        access_token = await integration_service.get_access_token(
            db, current_user.id, body.calendar_service
        )
        if access_token:
            try:
                external_id = await calendar_service.create_google_event(
                    access_token,
                    {
                        "title": event.title,
                        "description": event.description,
                        "start_time": event.start_time,
                        "end_time": event.end_time,
                        "location": event.location,
                        "attendees": event.attendees,
                    },
                )
                event.external_id = external_id
                event.status = "synced"
            except Exception:
                pass  # Calendar sync failure shouldn't block approval

    await db.commit()
    await db.refresh(event)
    return EventResponse.model_validate(event)


@router.post(
    "/{event_id}/reject",
    response_model=EventResponse,
    summary="Reject a suggested event",
)
async def reject_event(
    event_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> EventResponse:
    event = await _get_user_event(db, event_id, current_user.id)
    event.status = "rejected"
    await db.commit()
    await db.refresh(event)
    return EventResponse.model_validate(event)


# ── Private helper ─────────────────────────────────────────────────────────────

async def _get_user_event(
    db: AsyncSession, event_id: uuid.UUID, user_id: uuid.UUID
) -> Event:
    result = await db.execute(
        select(Event).where(Event.id == event_id, Event.user_id == user_id)
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event
