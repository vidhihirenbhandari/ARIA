from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, field_validator


class UserCreate(BaseModel):
    email: str
    name: str
    oauth_provider: str
    oauth_id: str
    avatar_url: Optional[str] = None


class UserUpdate(BaseModel):
    name: Optional[str] = None
    assistant_name: Optional[str] = None
    avatar_url: Optional[str] = None
    fcm_token: Optional[str] = None


class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    name: str
    assistant_name: str
    avatar_url: Optional[str] = None
    oauth_provider: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class UserProfile(UserResponse):
    """Extended profile including permission summary."""
    pass


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse
