import threading
import time
from collections.abc import Iterator

import pytest
import uvicorn

from waypoint_agent.server import create_app
from waypoint_agent.settings import Settings


@pytest.fixture
def agent_url() -> Iterator[str]:
    app = create_app(Settings(fake_llm=True))
    server = uvicorn.Server(uvicorn.Config(app, host="127.0.0.1", port=0, log_level="warning"))
    thread = threading.Thread(target=server.run)
    thread.start()
    while not server.started and thread.is_alive():
        time.sleep(0.01)
    port = server.servers[0].sockets[0].getsockname()[1]
    yield f"http://127.0.0.1:{port}"
    server.should_exit = True
    thread.join()
