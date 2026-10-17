"""The AG-UI endpoint of the order agent."""

import os
from pathlib import Path

import uvicorn
from ag_ui_adk import ADKAgent, add_adk_fastapi_endpoint
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from order_agent.agent import build_app

DEFAULT_PORT = "8000"
# Lets the app run in a browser too, once it has the web platform.
_LOCAL_ORIGIN = r"http://(localhost|127\.0\.0\.1)(:\d+)?"


def create_app() -> FastAPI:
    """The server, configured from the environment."""
    app = FastAPI(title="Tandem demo agent")
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=_LOCAL_ORIGIN,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    agent = ADKAgent.from_app(build_app(), use_in_memory_services=True)
    add_adk_fastapi_endpoint(app, agent, path="/agent")

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


def main() -> None:
    """`uv run order-agent`: serves on 127.0.0.1 and `PORT` (default 8000)."""
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
    uvicorn.run(create_app(), host="127.0.0.1", port=int(os.environ.get("PORT", DEFAULT_PORT)))
