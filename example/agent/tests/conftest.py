import threading
import time
from collections.abc import Iterator

import pytest
import uvicorn

from order_agent.server import create_app


@pytest.fixture
def agent_url(monkeypatch: pytest.MonkeyPatch) -> Iterator[str]:
    """The agent with the scripted model, which needs no network and no key, on a free port."""
    monkeypatch.setenv("TANDEM_FAKE_LLM", "1")
    monkeypatch.setenv("TANDEM_TODAY", "2026-10-16")
    server = uvicorn.Server(
        uvicorn.Config(create_app(), host="127.0.0.1", port=0, log_level="warning")
    )
    thread = threading.Thread(target=server.run)
    thread.start()
    while not server.started and thread.is_alive():
        time.sleep(0.01)
    port = server.servers[0].sockets[0].getsockname()[1]
    yield f"http://127.0.0.1:{port}"
    server.should_exit = True
    thread.join()
