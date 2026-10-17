from pathlib import Path

import uvicorn
from ag_ui_adk import ADKAgent, add_adk_fastapi_endpoint
from dotenv import load_dotenv
from fastapi import FastAPI

from order_agent.agent import build_app
from order_agent.settings import Settings


def create_app(settings: Settings) -> FastAPI:
    app = FastAPI(title="Tandem demo agent")
    agent = ADKAgent.from_app(build_app(settings), use_in_memory_services=True)
    add_adk_fastapi_endpoint(app, agent, path="/agent")
    return app


def main() -> None:
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
    settings = Settings()
    uvicorn.run(create_app(settings), host="127.0.0.1", port=settings.port)
