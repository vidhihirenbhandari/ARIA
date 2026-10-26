from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import List, Optional

from dateutil import parser as dateutil_parser


def parse_datetime(text: str) -> Optional[datetime]:
    """
    Attempt to parse a natural-language or ISO date string.
    Returns None if parsing fails.
    """
    if not text:
        return None
    try:
        dt = dateutil_parser.parse(text, fuzzy=True)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


def calculate_confidence(factors: List[float]) -> float:
    """
    Compute an aggregated confidence score from a list of factor scores.
    Each factor should be in [0.0, 1.0]. Uses geometric mean.
    """
    if not factors:
        return 0.0
    product = 1.0
    for f in factors:
        product *= max(0.0, min(1.0, f))
    return round(product ** (1.0 / len(factors)), 4)


def format_event_for_notification(event: dict) -> str:
    """Return a short human-readable string for a push notification."""
    title = event.get("title", "Event")
    start = event.get("start_time")
    location = event.get("location", "")

    if isinstance(start, datetime):
        time_str = start.strftime("%I:%M %p")
    elif isinstance(start, str):
        dt = parse_datetime(start)
        time_str = dt.strftime("%I:%M %p") if dt else start
    else:
        time_str = ""

    parts = [title]
    if time_str:
        parts.append(f"at {time_str}")
    if location:
        parts.append(f"@ {location}")
    return " ".join(parts)


# Common name patterns; intentionally simple — no heavyweight NLP dependency
_NAME_PATTERN = re.compile(
    r"\b(?:with|from|to|meeting|call|lunch|dinner|coffee)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)",
)
_INVITE_PATTERN = re.compile(r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\s+(?:invited|and)\b")


def extract_people_from_text(text: str) -> List[str]:
    """
    Heuristically extract person names from unstructured text.
    Returns a deduplicated list of candidate names.
    """
    found: list[str] = []
    for match in _NAME_PATTERN.finditer(text):
        found.append(match.group(1))
    for match in _INVITE_PATTERN.finditer(text):
        found.append(match.group(1))

    # Deduplicate while preserving order
    seen: set[str] = set()
    result: list[str] = []
    for name in found:
        if name not in seen:
            seen.add(name)
            result.append(name)
    return result
