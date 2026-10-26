from __future__ import annotations

import uuid
from datetime import datetime, timezone

import pytest
from httpx import AsyncClient

from app.models.user import User


FUTURE_TIME = datetime(2030, 6, 15, 10, 0, 0, tzinfo=timezone.utc)
FUTURE_TIME_END = datetime(2030, 6, 15, 11, 0, 0, tzinfo=timezone.utc)


@pytest.mark.asyncio
async def test_list_events_empty(client: AsyncClient, auth_headers: dict):
    resp = await client.get("/api/v1/events", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data
    assert isinstance(data["items"], list)


@pytest.mark.asyncio
async def test_create_event(client: AsyncClient, auth_headers: dict):
    payload = {
        "title": "Team Meeting",
        "start_time": FUTURE_TIME.isoformat(),
        "end_time": FUTURE_TIME_END.isoformat(),
        "location": "Conference Room A",
        "attendees": [{"name": "Alice", "email": "alice@example.com"}],
        "source": "manual",
    }
    resp = await client.post("/api/v1/events", json=payload, headers=auth_headers)
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "Team Meeting"
    assert data["status"] == "approved"
    assert data["location"] == "Conference Room A"
    return data["id"]


@pytest.mark.asyncio
async def test_get_event(client: AsyncClient, auth_headers: dict):
    # Create first
    payload = {
        "title": "Dentist Appointment",
        "start_time": FUTURE_TIME.isoformat(),
        "source": "manual",
    }
    create_resp = await client.post("/api/v1/events", json=payload, headers=auth_headers)
    event_id = create_resp.json()["id"]

    resp = await client.get(f"/api/v1/events/{event_id}", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["title"] == "Dentist Appointment"


@pytest.mark.asyncio
async def test_update_event(client: AsyncClient, auth_headers: dict):
    payload = {"title": "Original", "start_time": FUTURE_TIME.isoformat(), "source": "manual"}
    create_resp = await client.post("/api/v1/events", json=payload, headers=auth_headers)
    event_id = create_resp.json()["id"]

    update_resp = await client.put(
        f"/api/v1/events/{event_id}",
        json={"title": "Updated Title"},
        headers=auth_headers,
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["title"] == "Updated Title"


@pytest.mark.asyncio
async def test_delete_event(client: AsyncClient, auth_headers: dict):
    payload = {"title": "To Delete", "start_time": FUTURE_TIME.isoformat(), "source": "manual"}
    create_resp = await client.post("/api/v1/events", json=payload, headers=auth_headers)
    event_id = create_resp.json()["id"]

    del_resp = await client.delete(f"/api/v1/events/{event_id}", headers=auth_headers)
    assert del_resp.status_code == 200

    get_resp = await client.get(f"/api/v1/events/{event_id}", headers=auth_headers)
    assert get_resp.status_code == 404


@pytest.mark.asyncio
async def test_approve_event(client: AsyncClient, auth_headers: dict):
    # Create a pending event
    payload = {
        "title": "Pending Meeting",
        "start_time": FUTURE_TIME.isoformat(),
        "source": "ai_detected",
    }
    create_resp = await client.post("/api/v1/events", json=payload, headers=auth_headers)
    event_id = create_resp.json()["id"]

    # Approve
    approve_resp = await client.post(
        f"/api/v1/events/{event_id}/approve",
        json={"sync_to_calendar": False},
        headers=auth_headers,
    )
    assert approve_resp.status_code == 200
    assert approve_resp.json()["status"] == "approved"


@pytest.mark.asyncio
async def test_reject_event(client: AsyncClient, auth_headers: dict):
    payload = {"title": "Unwanted Event", "start_time": FUTURE_TIME.isoformat(), "source": "manual"}
    create_resp = await client.post("/api/v1/events", json=payload, headers=auth_headers)
    event_id = create_resp.json()["id"]

    reject_resp = await client.post(f"/api/v1/events/{event_id}/reject", headers=auth_headers)
    assert reject_resp.status_code == 200
    assert reject_resp.json()["status"] == "rejected"


@pytest.mark.asyncio
async def test_event_not_found(client: AsyncClient, auth_headers: dict):
    resp = await client.get(f"/api/v1/events/{uuid.uuid4()}", headers=auth_headers)
    assert resp.status_code == 404
