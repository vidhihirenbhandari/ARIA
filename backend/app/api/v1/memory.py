from __future__ import annotations

import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.memory import Memory
from app.models.user import User
from app.schemas.common import PaginatedResponse, SuccessResponse
from app.schemas.memory import (
    MemoryCreate,
    MemoryResponse,
    MemorySearchRequest,
    MemorySearchResult,
    MemoryUpdate,
)
from app.services.memory_service import memory_service

router = APIRouter(prefix="/memories", tags=["Memory"])


@router.get("", response_model=PaginatedResponse[MemoryResponse], summary="List memories")
async def list_memories(
    memory_type: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PaginatedResponse[MemoryResponse]:
    q = select(Memory).where(Memory.user_id == current_user.id)
    if memory_type:
        q = q.where(Memory.memory_type == memory_type)
    total = len((await db.execute(q)).scalars().all())
    q = q.order_by(Memory.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    rows = (await db.execute(q)).scalars().all()
    return PaginatedResponse(
        items=[MemoryResponse.model_validate(r) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
        has_next=(page * page_size) < total,
    )


@router.post(
    "",
    response_model=MemoryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Store a memory",
)
async def create_memory(
    body: MemoryCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MemoryResponse:
    embedding_id = await memory_service.store_memory(
        user_id=str(current_user.id),
        content=body.content,
        metadata={"tags": body.tags, "people": body.people_mentioned, "type": body.memory_type},
    )
    mem = Memory(
        user_id=current_user.id,
        embedding_id=embedding_id,
        **body.model_dump(),
    )
    db.add(mem)
    await db.commit()
    await db.refresh(mem)
    return MemoryResponse.model_validate(mem)


@router.post(
    "/search",
    response_model=List[MemorySearchResult],
    summary="Semantic search over memories",
)
async def search_memories(
    body: MemorySearchRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> List[MemorySearchResult]:
    results = await memory_service.search_memories(
        user_id=str(current_user.id),
        query=body.query,
        limit=body.limit,
    )
    output: list[MemorySearchResult] = []
    for point_id, score, content in results:
        # Try to find the DB record by embedding_id
        res = await db.execute(
            select(Memory).where(
                Memory.user_id == current_user.id,
                Memory.embedding_id == point_id,
            )
        )
        mem = res.scalar_one_or_none()
        if mem:
            output.append(
                MemorySearchResult(memory=MemoryResponse.model_validate(mem), score=score)
            )
    return output


@router.get("/{memory_id}", response_model=MemoryResponse, summary="Get memory")
async def get_memory(
    memory_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MemoryResponse:
    mem = await _get_user_memory(db, memory_id, current_user.id)
    return MemoryResponse.model_validate(mem)


@router.put("/{memory_id}", response_model=MemoryResponse, summary="Update memory")
async def update_memory(
    memory_id: uuid.UUID,
    body: MemoryUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MemoryResponse:
    mem = await _get_user_memory(db, memory_id, current_user.id)
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(mem, field, value)
    # Re-embed if content changed
    if body.content:
        new_id = await memory_service.store_memory(
            str(current_user.id), body.content,
            metadata={"tags": mem.tags, "people": mem.people_mentioned, "type": mem.memory_type},
        )
        if mem.embedding_id:
            await memory_service.delete_memory(mem.embedding_id)
        mem.embedding_id = new_id
    await db.commit()
    await db.refresh(mem)
    return MemoryResponse.model_validate(mem)


@router.delete("/{memory_id}", response_model=SuccessResponse, summary="Delete memory")
async def delete_memory(
    memory_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SuccessResponse:
    mem = await _get_user_memory(db, memory_id, current_user.id)
    if mem.embedding_id:
        await memory_service.delete_memory(mem.embedding_id)
    await db.delete(mem)
    await db.commit()
    return SuccessResponse(message="Memory deleted")


async def _get_user_memory(
    db: AsyncSession, memory_id: uuid.UUID, user_id: uuid.UUID
) -> Memory:
    result = await db.execute(
        select(Memory).where(Memory.id == memory_id, Memory.user_id == user_id)
    )
    mem = result.scalar_one_or_none()
    if not mem:
        raise HTTPException(status_code=404, detail="Memory not found")
    return mem
