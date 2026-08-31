from __future__ import annotations

import uuid
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel


class MemoryCreate(BaseModel):
    content: str
    tags: List[str] = []
    people_mentioned: List[str] = []
    memory_type: str = "note"


class MemoryUpdate(BaseModel):
    content: Optional[str] = None
    tags: Optional[List[str]] = None
    people_mentioned: Optional[List[str]] = None
    memory_type: Optional[str] = None


class MemoryResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    content: str
    embedding_id: Optional[str] = None
    tags: List[str] = []
    people_mentioned: List[str] = []
    memory_type: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MemorySearchRequest(BaseModel):
    query: str
    limit: int = 5
    memory_type: Optional[str] = None


class MemorySearchResult(BaseModel):
    memory: MemoryResponse
    score: float
