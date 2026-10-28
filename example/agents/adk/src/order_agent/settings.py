from pathlib import Path

from dotenv import load_dotenv
from order_desk.settings import Settings

__all__ = ["Settings", "load_settings"]


def load_settings() -> Settings:
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
    return Settings()
