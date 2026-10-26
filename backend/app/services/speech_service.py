from __future__ import annotations

import logging
from typing import Optional

logger = logging.getLogger(__name__)


class SpeechService:
    """Audio transcription via OpenAI Whisper API."""

    async def transcribe_audio(
        self, audio_bytes: bytes, filename: str = "audio.webm", language: Optional[str] = None
    ) -> str:
        """
        Transcribe audio bytes using OpenAI Whisper.
        Returns the transcribed text.
        """
        from app.core.config import settings

        if not settings.OPENAI_API_KEY:
            raise RuntimeError("OPENAI_API_KEY not configured")

        from openai import AsyncOpenAI

        client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

        # Whisper requires a file-like object with a name attribute
        import io

        audio_file = io.BytesIO(audio_bytes)
        audio_file.name = filename

        params = {"model": "whisper-1", "file": audio_file}
        if language:
            params["language"] = language

        try:
            transcript = await client.audio.transcriptions.create(**params)
            return transcript.text
        except Exception as exc:
            logger.error("Whisper transcription failed: %s", exc)
            raise


speech_service = SpeechService()
