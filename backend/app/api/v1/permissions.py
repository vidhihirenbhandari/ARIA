from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.permission import Permission
from app.models.user import User

router = APIRouter(prefix="/permissions", tags=["Permissions"])


class PermissionResponse(BaseModel):
    calendar_access: bool
    whatsapp_access: bool
    email_access: bool
    location_access: bool
    memory_storage: bool
    ai_processing: bool
    push_notifications: bool
    data_sharing: bool

    model_config = {"from_attributes": True}


class PermissionUpdate(BaseModel):
    calendar_access: Optional[bool] = None
    whatsapp_access: Optional[bool] = None
    email_access: Optional[bool] = None
    location_access: Optional[bool] = None
    memory_storage: Optional[bool] = None
    ai_processing: Optional[bool] = None
    push_notifications: Optional[bool] = None
    data_sharing: Optional[bool] = None


@router.get("", response_model=PermissionResponse, summary="Get user permissions")
async def get_permissions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PermissionResponse:
    perm = await _get_or_create_permissions(db, current_user)
    return PermissionResponse.model_validate(perm)


@router.put("", response_model=PermissionResponse, summary="Update user permissions")
async def update_permissions(
    body: PermissionUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PermissionResponse:
    perm = await _get_or_create_permissions(db, current_user)
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(perm, field, value)
    await db.commit()
    await db.refresh(perm)
    return PermissionResponse.model_validate(perm)


async def _get_or_create_permissions(db: AsyncSession, user: User) -> Permission:
    result = await db.execute(
        select(Permission).where(Permission.user_id == user.id)
    )
    perm = result.scalar_one_or_none()
    if perm is None:
        perm = Permission(user_id=user.id)
        db.add(perm)
        await db.commit()
        await db.refresh(perm)
    return perm
