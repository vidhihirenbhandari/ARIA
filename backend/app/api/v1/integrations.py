from __future__ import annotations

from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.integration import Integration
from app.models.user import User
from app.schemas.common import SuccessResponse
from app.services.integration_service import integration_service

router = APIRouter(prefix="/integrations", tags=["Integrations"])


class IntegrationResponse(BaseModel):
    service: str
    status: str
    metadata: Optional[Dict[str, Any]] = None

    model_config = {"from_attributes": True}


class ConnectRequest(BaseModel):
    service: str
    auth_code: str
    redirect_uri: str = ""


@router.get("", response_model=List[IntegrationResponse], summary="List connected integrations")
async def list_integrations(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> List[IntegrationResponse]:
    result = await db.execute(
        select(Integration).where(Integration.user_id == current_user.id)
    )
    rows = result.scalars().all()
    return [
        IntegrationResponse(
            service=r.service,
            status=r.status,
            metadata=r.metadata_json,
        )
        for r in rows
    ]


@router.post(
    "/connect",
    response_model=IntegrationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Connect an external service",
)
async def connect_integration(
    body: ConnectRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> IntegrationResponse:
    try:
        integration = await integration_service.connect_service(
            db,
            user_id=current_user.id,
            service=body.service,
            auth_code=body.auth_code,
            redirect_uri=body.redirect_uri,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"OAuth exchange failed: {exc}")

    return IntegrationResponse(
        service=integration.service,
        status=integration.status,
        metadata=integration.metadata_json,
    )


@router.get(
    "/{service}/status",
    response_model=IntegrationResponse,
    summary="Get integration status",
)
async def get_integration_status(
    service: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> IntegrationResponse:
    result = await db.execute(
        select(Integration).where(
            Integration.user_id == current_user.id, Integration.service == service
        )
    )
    row = result.scalar_one_or_none()
    if not row:
        return IntegrationResponse(service=service, status="disconnected")
    return IntegrationResponse(service=row.service, status=row.status, metadata=row.metadata_json)


@router.delete(
    "/{service}",
    response_model=SuccessResponse,
    summary="Disconnect an integration",
)
async def disconnect_integration(
    service: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SuccessResponse:
    disconnected = await integration_service.disconnect_service(db, current_user.id, service)
    if not disconnected:
        raise HTTPException(status_code=404, detail=f"Integration '{service}' not found")
    return SuccessResponse(message=f"{service} disconnected successfully")
