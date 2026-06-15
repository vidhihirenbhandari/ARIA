from __future__ import annotations

import logging
from datetime import timedelta
from typing import Any, Dict, Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.security import create_access_token
from app.models.permission import Permission
from app.models.user import User
from app.schemas.user import TokenResponse, UserResponse, UserUpdate

router = APIRouter(prefix="/auth", tags=["Authentication"])
logger = logging.getLogger(__name__)

GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo"
MICROSOFT_TOKEN_URL = "https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token"
MICROSOFT_USERINFO_URL = "https://graph.microsoft.com/v1.0/me"


# ── Helpers ────────────────────────────────────────────────────────────────────

async def _get_or_create_user(
    db: AsyncSession, email: str, name: str, oauth_provider: str, oauth_id: str,
    avatar_url: Optional[str] = None,
) -> User:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(
            email=email,
            name=name,
            oauth_provider=oauth_provider,
            oauth_id=oauth_id,
            avatar_url=avatar_url,
        )
        db.add(user)
        await db.flush()  # get the user.id before creating permission
        # Create default permissions
        perm = Permission(user_id=user.id)
        db.add(perm)
        await db.commit()
        await db.refresh(user)
    else:
        # Update name/avatar in case they changed
        user.name = name
        user.avatar_url = avatar_url or user.avatar_url
        await db.commit()
        await db.refresh(user)
    return user


def _build_token_response(user: User) -> TokenResponse:
    token = create_access_token(
        data={"sub": str(user.id), "email": user.email},
        expires_delta=timedelta(hours=settings.JWT_EXPIRY_HOURS),
    )
    return TokenResponse(
        access_token=token,
        expires_in=settings.JWT_EXPIRY_HOURS * 3600,
        user=UserResponse.model_validate(user),
    )


# ── Routes ─────────────────────────────────────────────────────────────────────

@router.post(
    "/google",
    response_model=TokenResponse,
    summary="Sign in with Google",
    description="Exchange a Google OAuth2 authorization code for an ARIA JWT.",
)
async def google_auth(
    payload: Dict[str, str],
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    code = payload.get("code")
    redirect_uri = payload.get("redirect_uri", "")
    if not code:
        raise HTTPException(status_code=400, detail="'code' is required")

    async with httpx.AsyncClient() as client:
        try:
            token_resp = await client.post(
                GOOGLE_TOKEN_URL,
                data={
                    "code": code,
                    "client_id": settings.GOOGLE_CLIENT_ID,
                    "client_secret": settings.GOOGLE_CLIENT_SECRET,
                    "redirect_uri": redirect_uri,
                    "grant_type": "authorization_code",
                },
                timeout=10.0,
            )
            token_resp.raise_for_status()
            token_data = token_resp.json()

            info_resp = await client.get(
                GOOGLE_USERINFO_URL,
                headers={"Authorization": f"Bearer {token_data['access_token']}"},
                timeout=10.0,
            )
            info_resp.raise_for_status()
            info = info_resp.json()
        except httpx.HTTPStatusError as exc:
            raise HTTPException(
                status_code=400, detail=f"Google OAuth failed: {exc.response.text}"
            )

    user = await _get_or_create_user(
        db,
        email=info["email"],
        name=info.get("name", info["email"]),
        oauth_provider="google",
        oauth_id=info["id"],
        avatar_url=info.get("picture"),
    )
    return _build_token_response(user)


@router.post(
    "/apple",
    response_model=TokenResponse,
    summary="Sign in with Apple",
)
async def apple_auth(
    payload: Dict[str, Any],
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """
    Apple Sign-In: expects {identity_token, user_info: {email, name}}.
    In production, validate the identity_token JWT against Apple's public keys.
    """
    identity_token = payload.get("identity_token")
    user_info = payload.get("user_info", {})

    if not identity_token:
        raise HTTPException(status_code=400, detail="'identity_token' is required")

    # Decode token (skip signature verification in this implementation)
    import base64
    import json as json_mod

    try:
        parts = identity_token.split(".")
        padded = parts[1] + "=" * (-len(parts[1]) % 4)
        claims = json_mod.loads(base64.urlsafe_b64decode(padded))
        email = claims.get("email") or user_info.get("email")
        oauth_id = claims.get("sub")
        if not email or not oauth_id:
            raise ValueError("Missing email or sub in token")
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid Apple identity token: {exc}")

    name = user_info.get("name") or email.split("@")[0]
    user = await _get_or_create_user(
        db, email=email, name=name, oauth_provider="apple", oauth_id=oauth_id
    )
    return _build_token_response(user)


@router.post(
    "/microsoft",
    response_model=TokenResponse,
    summary="Sign in with Microsoft",
)
async def microsoft_auth(
    payload: Dict[str, str],
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    code = payload.get("code")
    redirect_uri = payload.get("redirect_uri", "")
    if not code:
        raise HTTPException(status_code=400, detail="'code' is required")

    token_url = MICROSOFT_TOKEN_URL.format(tenant=settings.MICROSOFT_TENANT_ID)
    async with httpx.AsyncClient() as client:
        try:
            token_resp = await client.post(
                token_url,
                data={
                    "code": code,
                    "client_id": settings.MICROSOFT_CLIENT_ID,
                    "client_secret": settings.MICROSOFT_CLIENT_SECRET,
                    "redirect_uri": redirect_uri,
                    "grant_type": "authorization_code",
                    "scope": "openid profile email User.Read",
                },
                timeout=10.0,
            )
            token_resp.raise_for_status()
            token_data = token_resp.json()

            info_resp = await client.get(
                MICROSOFT_USERINFO_URL,
                headers={"Authorization": f"Bearer {token_data['access_token']}"},
                timeout=10.0,
            )
            info_resp.raise_for_status()
            info = info_resp.json()
        except httpx.HTTPStatusError as exc:
            raise HTTPException(
                status_code=400, detail=f"Microsoft OAuth failed: {exc.response.text}"
            )

    email = info.get("mail") or info.get("userPrincipalName")
    if not email:
        raise HTTPException(status_code=400, detail="Could not retrieve email from Microsoft")

    user = await _get_or_create_user(
        db,
        email=email,
        name=info.get("displayName", email),
        oauth_provider="microsoft",
        oauth_id=info["id"],
    )
    return _build_token_response(user)


@router.post(
    "/refresh",
    response_model=TokenResponse,
    summary="Refresh JWT",
)
async def refresh_token(
    current_user: User = Depends(get_current_user),
) -> TokenResponse:
    return _build_token_response(current_user)


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get current user profile",
)
async def get_me(current_user: User = Depends(get_current_user)) -> UserResponse:
    return UserResponse.model_validate(current_user)


@router.put(
    "/me",
    response_model=UserResponse,
    summary="Update user profile",
)
async def update_me(
    body: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserResponse:
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(current_user, field, value)
    await db.commit()
    await db.refresh(current_user)
    return UserResponse.model_validate(current_user)


@router.post(
    "/logout",
    summary="Logout (client should discard token)",
)
async def logout(current_user: User = Depends(get_current_user)) -> Dict[str, str]:
    # JWT is stateless; in production a Redis token blacklist would go here.
    return {"message": "Logged out successfully"}
