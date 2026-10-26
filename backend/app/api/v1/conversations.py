from __future__ import annotations

import uuid
from typing import AsyncGenerator, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.conversation import Conversation, Message
from app.models.user import User
from app.schemas.common import PaginatedResponse, SuccessResponse
from app.schemas.conversation import (
    ChatRequest,
    ConversationCreate,
    ConversationResponse,
    ConversationWithMessages,
    MessageResponse,
)
from app.services.ai_service import ai_service
from app.services.memory_service import memory_service

router = APIRouter(prefix="/conversations", tags=["Conversations"])


@router.get(
    "",
    response_model=PaginatedResponse[ConversationResponse],
    summary="List conversations",
)
async def list_conversations(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PaginatedResponse[ConversationResponse]:
    q = select(Conversation).where(Conversation.user_id == current_user.id)
    total = len((await db.execute(q)).scalars().all())
    q = q.order_by(Conversation.updated_at.desc()).offset((page - 1) * page_size).limit(page_size)
    rows = (await db.execute(q)).scalars().all()

    items = []
    for conv in rows:
        count_res = await db.execute(
            select(func.count()).where(Message.conversation_id == conv.id)
        )
        count = count_res.scalar() or 0
        items.append(
            ConversationResponse(
                **{c.key: getattr(conv, c.key) for c in conv.__table__.columns},
                message_count=count,
            )
        )

    return PaginatedResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        has_next=(page * page_size) < total,
    )


@router.post(
    "",
    response_model=ConversationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new conversation",
)
async def create_conversation(
    body: ConversationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ConversationResponse:
    conv = Conversation(user_id=current_user.id, title=body.title)
    db.add(conv)
    await db.commit()
    await db.refresh(conv)
    return ConversationResponse(**{c.key: getattr(conv, c.key) for c in conv.__table__.columns}, message_count=0)


@router.get(
    "/{conversation_id}",
    response_model=ConversationWithMessages,
    summary="Get conversation with messages",
)
async def get_conversation(
    conversation_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ConversationWithMessages:
    conv = await _get_user_conversation(db, conversation_id, current_user.id, load_messages=True)
    return ConversationWithMessages(
        **{c.key: getattr(conv, c.key) for c in conv.__table__.columns},
        message_count=len(conv.messages),
        messages=[MessageResponse.model_validate(m) for m in conv.messages],
    )


@router.get(
    "/{conversation_id}/messages",
    response_model=List[MessageResponse],
    summary="Get message history",
)
async def get_messages(
    conversation_id: uuid.UUID,
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> List[MessageResponse]:
    conv = await _get_user_conversation(db, conversation_id, current_user.id)
    result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conv.id)
        .order_by(Message.created_at.asc())
        .limit(limit)
    )
    return [MessageResponse.model_validate(m) for m in result.scalars().all()]


@router.post(
    "/{conversation_id}/messages",
    summary="Send a message and stream AI response (SSE)",
    response_class=StreamingResponse,
)
async def send_message(
    conversation_id: uuid.UUID,
    body: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    conv = await _get_user_conversation(db, conversation_id, current_user.id)

    # Save user message
    user_msg = Message(
        conversation_id=conv.id,
        role="user",
        content=body.message,
        audio_url=body.audio_url,
    )
    db.add(user_msg)
    await db.commit()

    # Build context from conversation history (last 20 messages)
    hist_result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conv.id)
        .order_by(Message.created_at.asc())
        .limit(20)
    )
    context = [
        {"role": m.role, "content": m.content}
        for m in hist_result.scalars().all()
        if m.id != user_msg.id
    ]

    # Get memory context
    mem_context = await memory_service.get_context_for_conversation(
        str(current_user.id), body.message
    )

    async def event_generator() -> AsyncGenerator[str, None]:
        full_response = []
        try:
            async for chunk in ai_service.chat(
                conversation_id=str(conversation_id),
                message=body.message,
                context=context,
                memory_context=mem_context,
            ):
                full_response.append(chunk)
                yield f"data: {chunk}\n\n"

            yield "data: [DONE]\n\n"

            # Save assistant response to DB (new session to avoid state issues)
            from app.core.database import async_session_factory

            async with async_session_factory() as save_db:
                assistant_msg = Message(
                    conversation_id=conv.id,
                    role="assistant",
                    content="".join(full_response),
                )
                save_db.add(assistant_msg)

                # Update conversation title if it's the first message
                if not conv.title:
                    first_words = body.message[:60]
                    conv_update = await save_db.get(Conversation, conv.id)
                    if conv_update:
                        conv_update.title = first_words + ("..." if len(body.message) > 60 else "")

                await save_db.commit()

                # Store the conversation exchange as memory if significant
                if len("".join(full_response)) > 50:
                    await memory_service.store_memory(
                        user_id=str(current_user.id),
                        content=f"User: {body.message}\nARIA: {''.join(full_response)}",
                        metadata={"type": "conversation", "conversation_id": str(conversation_id)},
                    )

        except Exception as exc:
            yield f"data: [ERROR] {str(exc)}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


@router.delete(
    "/{conversation_id}",
    response_model=SuccessResponse,
    summary="Delete conversation",
)
async def delete_conversation(
    conversation_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SuccessResponse:
    conv = await _get_user_conversation(db, conversation_id, current_user.id)
    await db.delete(conv)
    await db.commit()
    return SuccessResponse(message="Conversation deleted")


# ── Helper ─────────────────────────────────────────────────────────────────────

async def _get_user_conversation(
    db: AsyncSession,
    conversation_id: uuid.UUID,
    user_id: uuid.UUID,
    load_messages: bool = False,
) -> Conversation:
    q = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.user_id == user_id,
    )
    if load_messages:
        q = q.options(selectinload(Conversation.messages))
    result = await db.execute(q)
    conv = result.scalar_one_or_none()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conv
