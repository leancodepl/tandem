import uvicorn
from pydantic_ai.ui.ag_ui import AGUIAdapter
from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import Response
from starlette.routing import Route

from order_agent.agent import Screen, build_agent
from order_agent.settings import Settings, load_settings


def create_app(settings: Settings) -> Starlette:
    agent = build_agent(settings)

    async def run(request: Request) -> Response:
        adapter = await AGUIAdapter.from_request(request, agent=agent)
        screen = Screen([(entry.description, entry.value) for entry in adapter.run_input.context])
        return adapter.streaming_response(adapter.run_stream(deps=screen))

    return Starlette(routes=[Route("/agent", run, methods=["POST"])])


def main() -> None:
    settings = load_settings()
    uvicorn.run(create_app(settings), host=settings.host, port=settings.port)
