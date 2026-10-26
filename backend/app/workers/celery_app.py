from __future__ import annotations

from celery import Celery
from celery.schedules import crontab

from app.core.config import settings

celery_app = Celery(
    "aria",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
    include=["app.workers.tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    beat_schedule={
        "daily-briefings": {
            "task": "app.workers.tasks.send_daily_briefings",
            "schedule": crontab(hour=7, minute=0),  # 7 AM UTC daily
        },
        "cleanup-old-suggestions": {
            "task": "app.workers.tasks.cleanup_old_rejected_events",
            "schedule": crontab(hour=2, minute=0),  # 2 AM UTC daily
        },
    },
)
