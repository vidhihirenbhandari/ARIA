from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class AttendeeSchema(BaseModel):
    name: str
    email: Optional[str] = None


class EventCreate(BaseModel):
    title: str
    description: Optional[str] = None
    start_time: datetime
    end_time: Optional[datetime] = None
    location: Optional[str] = None
    attendees: List[AttendeeSchema] = []
    source: str = "manual"


class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    location: Optional[str] = None
    attendees: Optional[List[AttendeeSchema]] = None
    status: Optional[str] = None


class EventResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    title: str
    description: Optional[str] = None
    start_time: datetime
    end_time: Optional[datetime] = None
    location: Optional[str] = None
    attendees: List[Dict[str, Any]] = []
    source: str
    confidence_score: Optional[float] = None
    status: str
    external_id: Optional[str] = None
    raw_text: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class EventDetectRequest(BaseModel):
    text: str = Field(..., description="Natural language text to analyse for events")


class DetectedEvent(BaseModel):
    title: str
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    location: Optional[str] = None
    attendees: List[AttendeeSchema] = []
    confidence_score: float
    raw_text: str


class EventDetectResponse(BaseModel):
    events: List[DetectedEvent]
    overall_confidence: float


class EventApproveRequest(BaseModel):
    sync_to_calendar: bool = False
    calendar_service: Optional[str] = None  # google_calendar / outlook
