from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict, List

logger = logging.getLogger(__name__)


class TravelService:
    """Travel detection and management."""

    async def detect_travel_from_email(self, email_body: str) -> List[Dict[str, Any]]:
        """Use AI service to detect travel bookings in an email."""
        from app.services.ai_service import ai_service

        return await ai_service.detect_travel_from_email(email_body)

    async def get_upcoming_travel(
        self, db, user_id: str, limit: int = 10
    ) -> List[Any]:
        """Fetch upcoming travel from DB."""
        from uuid import UUID

        from sqlalchemy import select

        from app.models.travel import Travel

        now = datetime.now(timezone.utc)
        result = await db.execute(
            select(Travel)
            .where(
                Travel.user_id == UUID(user_id),
                Travel.status == "upcoming",
                Travel.departure_time >= now,
            )
            .order_by(Travel.departure_time)
            .limit(limit)
        )
        return result.scalars().all()

    def format_travel_for_briefing(self, travel: Any) -> Dict[str, Any]:
        return {
            "type": travel.travel_type,
            "departure": travel.departure_time.isoformat() if travel.departure_time else None,
            "details": travel.details,
        }


travel_service = TravelService()
