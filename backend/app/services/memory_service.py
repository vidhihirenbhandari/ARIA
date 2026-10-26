from __future__ import annotations

import hashlib
import logging
import uuid
from typing import Any, Dict, List, Optional, Tuple

from app.core.config import settings

logger = logging.getLogger(__name__)

_qdrant_client: Optional[Any] = None


def _get_qdrant():
    global _qdrant_client
    if _qdrant_client is None:
        try:
            from qdrant_client import QdrantClient
            from qdrant_client.models import Distance, VectorParams

            _qdrant_client = QdrantClient(url=settings.QDRANT_URL)
            # Ensure collection exists (dimension 1536 for OpenAI text-embedding-3-small)
            existing = [c.name for c in _qdrant_client.get_collections().collections]
            if settings.QDRANT_COLLECTION not in existing:
                _qdrant_client.create_collection(
                    collection_name=settings.QDRANT_COLLECTION,
                    vectors_config=VectorParams(size=1536, distance=Distance.COSINE),
                )
        except Exception as exc:
            logger.warning("Qdrant not available: %s", exc)
    return _qdrant_client


async def _embed(text: str) -> List[float]:
    """Generate an embedding vector using OpenAI."""
    if not settings.OPENAI_API_KEY:
        # Fallback: deterministic pseudo-embedding (dev only)
        digest = hashlib.sha256(text.encode()).digest()
        base = list(digest) * (1536 // 32)
        return [b / 255.0 for b in base[:1536]]

    from openai import AsyncOpenAI

    client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
    resp = await client.embeddings.create(
        model="text-embedding-3-small", input=text
    )
    return resp.data[0].embedding


class MemoryService:
    """Vector-based memory storage and retrieval using Qdrant."""

    async def store_memory(
        self,
        user_id: str,
        content: str,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> str:
        """Embed content and upsert into Qdrant. Returns the point ID."""
        point_id = str(uuid.uuid4())
        embedding = await _embed(content)

        client = _get_qdrant()
        if client is None:
            logger.warning("Qdrant unavailable; memory not stored in vector DB")
            return point_id

        from qdrant_client.models import PointStruct

        payload = {"user_id": user_id, "content": content}
        if metadata:
            payload.update(metadata)

        client.upsert(
            collection_name=settings.QDRANT_COLLECTION,
            points=[PointStruct(id=point_id, vector=embedding, payload=payload)],
        )
        return point_id

    async def search_memories(
        self,
        user_id: str,
        query: str,
        limit: int = 5,
    ) -> List[Tuple[str, float, str]]:
        """
        Semantic search over the user's memories.
        Returns list of (memory_id_or_point_id, score, content).
        """
        client = _get_qdrant()
        if client is None:
            return []

        embedding = await _embed(query)
        try:
            results = client.search(
                collection_name=settings.QDRANT_COLLECTION,
                query_vector=embedding,
                query_filter={
                    "must": [{"key": "user_id", "match": {"value": user_id}}]
                },
                limit=limit,
                with_payload=True,
            )
            return [
                (str(r.id), r.score, r.payload.get("content", ""))
                for r in results
            ]
        except Exception as exc:
            logger.warning("Qdrant search failed: %s", exc)
            return []

    async def get_context_for_conversation(
        self, user_id: str, message: str, limit: int = 5
    ) -> str:
        """Build a memory-context string to inject into the AI system prompt."""
        results = await self.search_memories(user_id, message, limit=limit)
        if not results:
            return ""
        lines = [f"- {content} (relevance: {score:.2f})" for _, score, content in results]
        return "\n".join(lines)

    async def delete_memory(self, embedding_id: str) -> None:
        client = _get_qdrant()
        if client is None:
            return
        try:
            client.delete(
                collection_name=settings.QDRANT_COLLECTION,
                points_selector=[embedding_id],
            )
        except Exception as exc:
            logger.warning("Failed to delete memory from Qdrant: %s", exc)


memory_service = MemoryService()
