from __future__ import annotations

import pytest
from httpx import AsyncClient

from app.models.user import User


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    resp = await client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert "version" in data


@pytest.mark.asyncio
async def test_get_me_unauthenticated(client: AsyncClient):
    resp = await client.get("/api/v1/auth/me")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_get_me_authenticated(client: AsyncClient, auth_headers: dict, sample_user: User):
    resp = await client.get("/api/v1/auth/me", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["email"] == sample_user.email
    assert data["name"] == sample_user.name


@pytest.mark.asyncio
async def test_update_profile(client: AsyncClient, auth_headers: dict):
    resp = await client.put(
        "/api/v1/auth/me",
        json={"assistant_name": "Jarvis"},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["assistant_name"] == "Jarvis"


@pytest.mark.asyncio
async def test_refresh_token(client: AsyncClient, auth_headers: dict):
    resp = await client.post("/api/v1/auth/refresh", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_logout(client: AsyncClient, auth_headers: dict):
    resp = await client.post("/api/v1/auth/logout", headers=auth_headers)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_google_auth_missing_code(client: AsyncClient):
    resp = await client.post("/api/v1/auth/google", json={})
    assert resp.status_code == 400
