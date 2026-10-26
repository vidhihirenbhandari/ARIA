from __future__ import annotations

import uuid
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from app.models.user import User


@pytest.mark.asyncio
async def test_list_conversations_empty(client: AsyncClient, auth_headers: dict):
    resp = await client.get("/api/v1/conversations", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data


@pytest.mark.asyncio
async def test_create_conversation(client: AsyncClient, auth_headers: dict):
    resp = await client.post(
        "/api/v1/conversations",
        json={"title": "My First Chat"},
        headers=auth_headers,
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "My First Chat"
    assert "id" in data
    return data["id"]


@pytest.mark.asyncio
async def test_get_conversation(client: AsyncClient, auth_headers: dict):
    create_resp = await client.post(
        "/api/v1/conversations",
        json={"title": "Test Convo"},
        headers=auth_headers,
    )
    conv_id = create_resp.json()["id"]

    resp = await client.get(f"/api/v1/conversations/{conv_id}", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["title"] == "Test Convo"


@pytest.mark.asyncio
async def test_get_messages_empty(client: AsyncClient, auth_headers: dict):
    create_resp = await client.post(
        "/api/v1/conversations", json={}, headers=auth_headers
    )
    conv_id = create_resp.json()["id"]

    resp = await client.get(f"/api/v1/conversations/{conv_id}/messages", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_delete_conversation(client: AsyncClient, auth_headers: dict):
    create_resp = await client.post(
        "/api/v1/conversations", json={"title": "To Delete"}, headers=auth_headers
    )
    conv_id = create_resp.json()["id"]

    del_resp = await client.delete(f"/api/v1/conversations/{conv_id}", headers=auth_headers)
    assert del_resp.status_code == 200

    get_resp = await client.get(f"/api/v1/conversations/{conv_id}", headers=auth_headers)
    assert get_resp.status_code == 404


@pytest.mark.asyncio
async def test_conversation_not_found(client: AsyncClient, auth_headers: dict):
    resp = await client.get(f"/api/v1/conversations/{uuid.uuid4()}", headers=auth_headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_send_message_streams(client: AsyncClient, auth_headers: dict):
    """Test SSE streaming endpoint with a mocked AI service."""
    create_resp = await client.post(
        "/api/v1/conversations", json={"title": "Stream Test"}, headers=auth_headers
    )
    conv_id = create_resp.json()["id"]

    async def mock_chat(*args, **kwargs):
        for chunk in ["Hello", " there", "!"]:
            yield chunk

    with patch("app.api.v1.conversations.ai_service.chat", side_effect=mock_chat):
        with patch("app.api.v1.conversations.memory_service.get_context_for_conversation", new_callable=AsyncMock, return_value=""):
            resp = await client.post(
                f"/api/v1/conversations/{conv_id}/messages",
                json={"message": "Hi ARIA!"},
                headers=auth_headers,
            )
    assert resp.status_code == 200
    assert "text/event-stream" in resp.headers["content-type"]
    content = resp.text
    assert "Hello" in content or "data:" in content
