from fastapi import APIRouter

from app.api.v1 import (
    auth,
    conversations,
    events,
    integrations,
    memory,
    notifications,
    permissions,
    tasks,
    travel,
)
from app.api.v1.briefing import router as briefing_router
from app.api.v1.webhooks import router as webhooks_router

api_router = APIRouter()

api_router.include_router(auth.router)
api_router.include_router(events.router)
api_router.include_router(tasks.router)
api_router.include_router(memory.router)
api_router.include_router(conversations.router)
api_router.include_router(travel.router)
api_router.include_router(permissions.router)
api_router.include_router(notifications.router)
api_router.include_router(integrations.router)
api_router.include_router(briefing_router, tags=["Briefing"])
api_router.include_router(webhooks_router, tags=["Webhooks"])
