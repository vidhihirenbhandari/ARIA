from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, AsyncGenerator, Dict, List, Optional

import anthropic

from app.core.config import settings

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are ARIA (Adaptive Real-time Intelligence System), a highly capable AI personal assistant. You are warm, concise, and proactive. You help users manage their calendar, tasks, memories, travel, and daily life.

When detecting events or commitments from text:
- Extract specific dates, times, locations, and people mentioned
- Assess confidence based on how explicit the information is
- Always output structured JSON when asked to

When chatting:
- Be helpful, friendly, and concise
- Reference past context when relevant
- Proactively suggest actions (adding events, setting reminders)
"""

INTENT_DETECTION_PROMPT = """Analyze the following text and detect intents. Return a JSON object with this exact structure:
{
  "intent_type": "meeting|task|travel|query|reminder|other",
  "confidence": 0.0-1.0,
  "entities": {
    "person": "name of person if mentioned",
    "time": "ISO 8601 datetime string if detected, null otherwise",
    "end_time": "ISO 8601 datetime string if detected, null otherwise",
    "location": "location string if mentioned, null otherwise",
    "title": "brief title for the event/task",
    "attendees": [{"name": "...", "email": null}]
  },
  "suggested_action": "Brief description of what ARIA should do"
}

Text to analyze:
"""

EVENT_EXTRACT_PROMPT = """Extract calendar events from the following text. Return a JSON array where each item has:
{
  "title": "event title",
  "start_time": "ISO 8601 datetime or null",
  "end_time": "ISO 8601 datetime or null",
  "location": "location or null",
  "attendees": [{"name": "...", "email": null}],
  "confidence": 0.0-1.0,
  "raw_text": "relevant portion of original text"
}

If no events are found, return an empty array [].

Text:
"""

DAILY_BRIEFING_PROMPT = """Generate a concise, friendly daily briefing for the user. Be warm and personalized.
Structure your response as JSON:
{
  "greeting": "Personalized good morning/afternoon/evening message",
  "events_summary": "Brief summary of today's events (1-2 sentences)",
  "tasks_summary": "Brief summary of pending tasks (1-2 sentences)",
  "travel_summary": "Brief travel info if any (1 sentence or empty string)",
  "ai_summary": "Overall helpful narrative tying it together (2-3 sentences)"
}

Current time: {current_time}
Events today: {events}
Tasks due: {tasks}
Travel: {travel}
"""


@dataclass
class IntentResult:
    intent_type: str  # meeting / task / travel / query / reminder / other
    confidence: float
    entities: Dict[str, Any]
    suggested_action: str


@dataclass
class DailyBriefing:
    greeting: str
    events_today: List[Dict[str, Any]]
    tasks_due: List[Dict[str, Any]]
    travel_info: List[Dict[str, Any]]
    ai_summary: str


class AIService:
    """Wrapper around the Anthropic API for ARIA AI features."""

    def __init__(self) -> None:
        self.client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
        self.model = "claude-sonnet-4-6"

    # ── Intent detection ───────────────────────────────────────────────────

    async def detect_intent(self, text: str) -> IntentResult:
        """Use Claude to identify intent and extract structured entities."""
        try:
            message = await self.client.messages.create(
                model=self.model,
                max_tokens=512,
                system=SYSTEM_PROMPT,
                messages=[
                    {
                        "role": "user",
                        "content": INTENT_DETECTION_PROMPT + text,
                    }
                ],
            )
            raw = message.content[0].text.strip()
            # Strip potential markdown code fences
            if raw.startswith("```"):
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
            data = json.loads(raw)
            return IntentResult(
                intent_type=data.get("intent_type", "other"),
                confidence=float(data.get("confidence", 0.5)),
                entities=data.get("entities", {}),
                suggested_action=data.get("suggested_action", ""),
            )
        except Exception as exc:
            logger.warning("detect_intent failed: %s", exc)
            return IntentResult(
                intent_type="other",
                confidence=0.0,
                entities={},
                suggested_action="",
            )

    # ── Streaming chat ─────────────────────────────────────────────────────

    async def chat(
        self,
        conversation_id: str,
        message: str,
        context: List[Dict[str, str]],
        memory_context: str = "",
    ) -> AsyncGenerator[str, None]:
        """Yield streaming text chunks from Claude."""
        system = SYSTEM_PROMPT
        if memory_context:
            system += f"\n\nRelevant memories about the user:\n{memory_context}"

        messages = context[-20:]  # keep last 20 turns max
        messages.append({"role": "user", "content": message})

        async with self.client.messages.stream(
            model=self.model,
            max_tokens=1024,
            system=system,
            messages=messages,
        ) as stream:
            async for text in stream.text_stream:
                yield text

    # ── Event extraction ───────────────────────────────────────────────────

    async def extract_event_from_text(self, text: str) -> List[Dict[str, Any]]:
        """Extract structured event data from natural-language text."""
        try:
            message = await self.client.messages.create(
                model=self.model,
                max_tokens=1024,
                system=SYSTEM_PROMPT,
                messages=[
                    {"role": "user", "content": EVENT_EXTRACT_PROMPT + text}
                ],
            )
            raw = message.content[0].text.strip()
            if raw.startswith("```"):
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
            events = json.loads(raw)
            if not isinstance(events, list):
                events = []
            return events
        except Exception as exc:
            logger.warning("extract_event_from_text failed: %s", exc)
            return []

    # ── Daily briefing ─────────────────────────────────────────────────────

    async def generate_daily_briefing(
        self,
        events: List[Dict[str, Any]],
        tasks: List[Dict[str, Any]],
        travel: List[Dict[str, Any]],
    ) -> DailyBriefing:
        """Generate a personalised daily briefing for the user."""
        prompt = DAILY_BRIEFING_PROMPT.format(
            current_time=datetime.now().isoformat(),
            events=json.dumps(events, default=str),
            tasks=json.dumps(tasks, default=str),
            travel=json.dumps(travel, default=str),
        )
        try:
            message = await self.client.messages.create(
                model=self.model,
                max_tokens=512,
                system=SYSTEM_PROMPT,
                messages=[{"role": "user", "content": prompt}],
            )
            raw = message.content[0].text.strip()
            if raw.startswith("```"):
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
            data = json.loads(raw)
            return DailyBriefing(
                greeting=data.get("greeting", "Good morning!"),
                events_today=events,
                tasks_due=tasks,
                travel_info=travel,
                ai_summary=data.get("ai_summary", ""),
            )
        except Exception as exc:
            logger.warning("generate_daily_briefing failed: %s", exc)
            return DailyBriefing(
                greeting="Good morning!",
                events_today=events,
                tasks_due=tasks,
                travel_info=travel,
                ai_summary="Here's your day at a glance.",
            )

    # ── Travel detection from email ────────────────────────────────────────

    async def detect_travel_from_email(self, email_body: str) -> List[Dict[str, Any]]:
        """Extract travel bookings from an email body."""
        prompt = """Extract travel booking information from the following email. Return a JSON array where each item has:
{
  "travel_type": "flight|hotel|train|car_rental",
  "details": {
    "airline": null,
    "flight_no": null,
    "from": null,
    "to": null,
    "booking_ref": null,
    "seat": null,
    "class": null,
    "hotel_name": null,
    "check_in": null,
    "check_out": null,
    "confirmation_no": null
  },
  "departure_time": "ISO 8601 or null",
  "arrival_time": "ISO 8601 or null"
}

If no travel info found, return [].

Email:
""" + email_body

        try:
            message = await self.client.messages.create(
                model=self.model,
                max_tokens=1024,
                messages=[{"role": "user", "content": prompt}],
            )
            raw = message.content[0].text.strip()
            if raw.startswith("```"):
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
            items = json.loads(raw)
            return items if isinstance(items, list) else []
        except Exception as exc:
            logger.warning("detect_travel_from_email failed: %s", exc)
            return []


# Singleton
ai_service = AIService()
