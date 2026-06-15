from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

import httpx

logger = logging.getLogger(__name__)

GOOGLE_CALENDAR_API = "https://www.googleapis.com/calendar/v3"


class CalendarService:
    """Google Calendar / Outlook integration."""

    # ── Google Calendar ────────────────────────────────────────────────────

    async def sync_google_calendar(
        self, user_id: str, access_token: str, days: int = 7
    ) -> List[Dict[str, Any]]:
        """Fetch upcoming events from Google Calendar."""
        now = datetime.now(timezone.utc)
        time_min = now.isoformat()
        time_max = (now + timedelta(days=days)).isoformat()

        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{GOOGLE_CALENDAR_API}/calendars/primary/events",
                headers={"Authorization": f"Bearer {access_token}"},
                params={
                    "timeMin": time_min,
                    "timeMax": time_max,
                    "singleEvents": "true",
                    "orderBy": "startTime",
                    "maxResults": 100,
                },
                timeout=10.0,
            )
            resp.raise_for_status()
            data = resp.json()

        events = []
        for item in data.get("items", []):
            start = item.get("start", {})
            end = item.get("end", {})
            events.append(
                {
                    "external_id": item.get("id"),
                    "title": item.get("summary", "Untitled"),
                    "description": item.get("description"),
                    "location": item.get("location"),
                    "start_time": start.get("dateTime") or start.get("date"),
                    "end_time": end.get("dateTime") or end.get("date"),
                    "attendees": [
                        {"name": a.get("displayName", ""), "email": a.get("email")}
                        for a in item.get("attendees", [])
                    ],
                    "source": "calendar_sync",
                    "status": "approved",
                }
            )
        return events

    async def create_google_event(
        self, access_token: str, event_data: Dict[str, Any]
    ) -> str:
        """Create an event in Google Calendar and return its ID."""
        body: Dict[str, Any] = {
            "summary": event_data.get("title", ""),
            "description": event_data.get("description", ""),
            "location": event_data.get("location", ""),
            "start": {
                "dateTime": _to_iso(event_data.get("start_time")),
                "timeZone": "UTC",
            },
            "end": {
                "dateTime": _to_iso(
                    event_data.get("end_time") or event_data.get("start_time")
                ),
                "timeZone": "UTC",
            },
            "attendees": [
                {"email": a.get("email"), "displayName": a.get("name")}
                for a in event_data.get("attendees", [])
                if a.get("email")
            ],
        }

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{GOOGLE_CALENDAR_API}/calendars/primary/events",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json",
                },
                json=body,
                timeout=10.0,
            )
            resp.raise_for_status()
            return resp.json()["id"]

    async def delete_google_event(self, access_token: str, event_id: str) -> None:
        async with httpx.AsyncClient() as client:
            resp = await client.delete(
                f"{GOOGLE_CALENDAR_API}/calendars/primary/events/{event_id}",
                headers={"Authorization": f"Bearer {access_token}"},
                timeout=10.0,
            )
            resp.raise_for_status()


def _to_iso(value: Any) -> str:
    if isinstance(value, datetime):
        return value.isoformat()
    if value is None:
        return datetime.now(timezone.utc).isoformat()
    return str(value)


calendar_service = CalendarService()
