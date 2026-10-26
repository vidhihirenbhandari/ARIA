from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Dict, Optional

from pydantic import BaseModel


class TravelCreate(BaseModel):
    travel_type: str  # flight / hotel / train / car_rental
    details: Dict[str, Any] = {}
    departure_time: Optional[datetime] = None
    arrival_time: Optional[datetime] = None
    source: str = "manual"


class TravelUpdate(BaseModel):
    details: Optional[Dict[str, Any]] = None
    departure_time: Optional[datetime] = None
    arrival_time: Optional[datetime] = None
    status: Optional[str] = None


class TravelResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    travel_type: str
    details: Dict[str, Any]
    departure_time: Optional[datetime] = None
    arrival_time: Optional[datetime] = None
    status: str
    source: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class TravelDetectRequest(BaseModel):
    email_body: str
