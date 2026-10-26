from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional
from uuid import UUID

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import decrypt_data, encrypt_data
from app.models.integration import Integration

logger = logging.getLogger(__name__)

GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
MICROSOFT_TOKEN_URL = "https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token"


class IntegrationService:
    """Manage OAuth connections to external services."""

    async def connect_google_calendar(
        self,
        db: AsyncSession,
        user_id: UUID,
        auth_code: str,
        redirect_uri: str,
    ) -> Integration:
        """Exchange Google auth code for tokens and save integration."""
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                GOOGLE_TOKEN_URL,
                data={
                    "code": auth_code,
                    "client_id": settings.GOOGLE_CLIENT_ID,
                    "client_secret": settings.GOOGLE_CLIENT_SECRET,
                    "redirect_uri": redirect_uri,
                    "grant_type": "authorization_code",
                },
            )
            resp.raise_for_status()
            token_data = resp.json()

        # Get user profile to store the email
        user_info = {}
        try:
            async with httpx.AsyncClient() as client:
                info_resp = await client.get(
                    "https://www.googleapis.com/oauth2/v2/userinfo",
                    headers={"Authorization": f"Bearer {token_data['access_token']}"},
                )
                user_info = info_resp.json()
        except Exception:
            pass

        return await self._upsert_integration(
            db,
            user_id=user_id,
            service="google_calendar",
            access_token=token_data.get("access_token", ""),
            refresh_token=token_data.get("refresh_token", ""),
            expires_in=token_data.get("expires_in", 3600),
            metadata={"email": user_info.get("email"), "calendar_id": "primary"},
        )

    async def connect_service(
        self,
        db: AsyncSession,
        user_id: UUID,
        service: str,
        auth_code: str,
        redirect_uri: str = "",
    ) -> Integration:
        """Generic connect — routes to provider-specific logic."""
        if service == "google_calendar":
            return await self.connect_google_calendar(db, user_id, auth_code, redirect_uri)
        raise ValueError(f"Unsupported service: {service}")

    async def disconnect_service(
        self, db: AsyncSession, user_id: UUID, service: str
    ) -> bool:
        result = await db.execute(
            select(Integration).where(
                Integration.user_id == user_id,
                Integration.service == service,
            )
        )
        integration = result.scalar_one_or_none()
        if not integration:
            return False
        integration.status = "disconnected"
        integration.access_token_encrypted = None
        integration.refresh_token_encrypted = None
        await db.commit()
        return True

    async def refresh_token(self, db: AsyncSession, integration_id: UUID) -> bool:
        result = await db.execute(
            select(Integration).where(Integration.id == integration_id)
        )
        integration = result.scalar_one_or_none()
        if not integration or not integration.refresh_token_encrypted:
            return False

        refresh_token = decrypt_data(integration.refresh_token_encrypted)
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    GOOGLE_TOKEN_URL,
                    data={
                        "refresh_token": refresh_token,
                        "client_id": settings.GOOGLE_CLIENT_ID,
                        "client_secret": settings.GOOGLE_CLIENT_SECRET,
                        "grant_type": "refresh_token",
                    },
                )
                resp.raise_for_status()
                token_data = resp.json()

            integration.access_token_encrypted = encrypt_data(token_data["access_token"])
            integration.token_expiry = datetime.now(timezone.utc).replace(
                second=0, microsecond=0
            )
            integration.status = "connected"
            await db.commit()
            return True
        except Exception as exc:
            logger.error("Token refresh failed: %s", exc)
            integration.status = "error"
            await db.commit()
            return False

    async def get_access_token(
        self, db: AsyncSession, user_id: UUID, service: str
    ) -> Optional[str]:
        """Return a decrypted, valid access token for the service."""
        result = await db.execute(
            select(Integration).where(
                Integration.user_id == user_id,
                Integration.service == service,
                Integration.status == "connected",
            )
        )
        integration = result.scalar_one_or_none()
        if not integration or not integration.access_token_encrypted:
            return None

        # Refresh if expired
        if integration.token_expiry and integration.token_expiry < datetime.now(timezone.utc):
            refreshed = await self.refresh_token(db, integration.id)
            if not refreshed:
                return None
            await db.refresh(integration)

        return decrypt_data(integration.access_token_encrypted)

    # ── Helpers ────────────────────────────────────────────────────────────

    async def _upsert_integration(
        self,
        db: AsyncSession,
        user_id: UUID,
        service: str,
        access_token: str,
        refresh_token: str,
        expires_in: int,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> Integration:
        from datetime import timedelta

        result = await db.execute(
            select(Integration).where(
                Integration.user_id == user_id, Integration.service == service
            )
        )
        integration = result.scalar_one_or_none()
        expiry = datetime.now(timezone.utc) + timedelta(seconds=expires_in)

        if integration is None:
            integration = Integration(
                user_id=user_id,
                service=service,
                status="connected",
                access_token_encrypted=encrypt_data(access_token) if access_token else None,
                refresh_token_encrypted=encrypt_data(refresh_token) if refresh_token else None,
                token_expiry=expiry,
                metadata_json=metadata,
            )
            db.add(integration)
        else:
            integration.status = "connected"
            integration.access_token_encrypted = encrypt_data(access_token) if access_token else None
            if refresh_token:
                integration.refresh_token_encrypted = encrypt_data(refresh_token)
            integration.token_expiry = expiry
            if metadata:
                integration.metadata_json = metadata

        await db.commit()
        await db.refresh(integration)
        return integration


integration_service = IntegrationService()
