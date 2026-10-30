import uvicorn
from ag_ui_adk import ADKAgent, add_adk_fastapi_endpoint
from fastapi import FastAPI

from waypoint_agent.agent import build_app
from waypoint_agent.instruction import Screen
from waypoint_agent.settings import Settings, load_settings

_PATHS = {
    Screen.TRIP: "/agent",
    Screen.BOOKING: "/agent/booking",
    Screen.PLAN: "/agent/plan",
    Screen.EXPENSES: "/agent/expenses",
    Screen.ARRIVAL: "/agent/arrival",
}


def create_app(settings: Settings) -> FastAPI:
    app = FastAPI(title="Waypoint agent")
    for screen, path in _PATHS.items():
        agent = ADKAgent.from_app(build_app(settings, screen), use_in_memory_services=True)
        add_adk_fastapi_endpoint(app, agent, path=path)
    return app


def main() -> None:
    settings = load_settings()
    uvicorn.run(create_app(settings), host=settings.host, port=settings.port)
