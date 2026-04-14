"""Application configuration via environment variables."""

from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables and .env file."""
    
    APP_NAME: str = "Ghost Coach"
    DEBUG: bool = False
    VJEPA_MODEL_NAME: str = "vjepa2_vit_large"
    DEVICE: str = "cuda"
    MAX_VIDEO_DURATION_SECONDS: int = 30
    MAX_FILE_SIZE_MB: int = 100
    NUM_FRAMES: int = 16
    RESOLUTION: int = 224
    GEMINI_API_KEY: Optional[str] = None
    UPLOAD_DIR: str = "/tmp/ghost_coach"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
    )


@lru_cache
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()