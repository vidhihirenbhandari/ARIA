from __future__ import annotations

from typing import Generic, List, Optional, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class PaginationParams(BaseModel):
    page: int = 1
    page_size: int = 20


class PaginatedResponse(BaseModel, Generic[T]):
    items: List[T]
    total: int
    page: int
    page_size: int
    has_next: bool


class SuccessResponse(BaseModel):
    success: bool = True
    message: str = ""


class ErrorResponse(BaseModel):
    error: str
    detail: str = ""
