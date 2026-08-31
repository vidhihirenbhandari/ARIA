from __future__ import annotations

import uuid
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.travel import Travel
from app.models.user import User
from app.schemas.common import PaginatedResponse, SuccessResponse
from app.schemas.travel import TravelCreate, TravelDetectRequest, TravelResponse, TravelUpdate
from app.services.travel_service import travel_service
from app.utils.helpers import parse_datetime

router = APIRouter(prefix="/travel", tags=["Travel"])


@router.get("", response_model=PaginatedResponse[TravelResponse], summary="List travel bookings")
async def list_travel(
    status_filter: Optional[str] = Query(None, alias="status"),
    travel_type: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PaginatedResponse[TravelResponse]:
    q = select(Travel).where(Travel.user_id == current_user.id)
    if status_filter:
        q = q.where(Travel.status == status_filter)
    if travel_type:
        q = q.where(Travel.travel_type == travel_type)
    total = len((await db.execute(q)).scalars().all())
    q = q.order_by(Travel.departure_time.asc().nullslast()).offset((page - 1) * page_size).limit(page_size)
    rows = (await db.execute(q)).scalars().all()
    return PaginatedResponse(
        items=[TravelResponse.model_validate(r) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
        has_next=(page * page_size) < total,
    )


@router.post(
    "",
    response_model=TravelResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add travel booking manually",
)
async def create_travel(
    body: TravelCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TravelResponse:
    t = Travel(user_id=current_user.id, **body.model_dump())
    db.add(t)
    await db.commit()
    await db.refresh(t)
    return TravelResponse.model_validate(t)


@router.post(
    "/detect",
    response_model=List[TravelResponse],
    summary="Detect travel bookings from email text",
)
async def detect_travel(
    body: TravelDetectRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> List[TravelResponse]:
    detected = await travel_service.detect_travel_from_email(body.email_body)
    saved = []
    for item in detected:
        t = Travel(
            user_id=current_user.id,
            travel_type=item.get("travel_type", "flight"),
            details=item.get("details", {}),
            departure_time=parse_datetime(item.get("departure_time") or ""),
            arrival_time=parse_datetime(item.get("arrival_time") or ""),
            source="email",
        )
        db.add(t)
        saved.append(t)
    if saved:
        await db.commit()
        for t in saved:
            await db.refresh(t)
    return [TravelResponse.model_validate(t) for t in saved]


@router.get("/{travel_id}", response_model=TravelResponse, summary="Get travel booking")
async def get_travel(
    travel_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TravelResponse:
    t = await _get_user_travel(db, travel_id, current_user.id)
    return TravelResponse.model_validate(t)


@router.put("/{travel_id}", response_model=TravelResponse, summary="Update travel booking")
async def update_travel(
    travel_id: uuid.UUID,
    body: TravelUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TravelResponse:
    t = await _get_user_travel(db, travel_id, current_user.id)
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(t, field, value)
    await db.commit()
    await db.refresh(t)
    return TravelResponse.model_validate(t)


@router.delete("/{travel_id}", response_model=SuccessResponse, summary="Delete travel booking")
async def delete_travel(
    travel_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SuccessResponse:
    t = await _get_user_travel(db, travel_id, current_user.id)
    await db.delete(t)
    await db.commit()
    return SuccessResponse(message="Travel booking deleted")


async def _get_user_travel(
    db: AsyncSession, travel_id: uuid.UUID, user_id: uuid.UUID
) -> Travel:
    result = await db.execute(
        select(Travel).where(Travel.id == travel_id, Travel.user_id == user_id)
    )
    t = result.scalar_one_or_none()
    if not t:
        raise HTTPException(status_code=404, detail="Travel booking not found")
    return t
