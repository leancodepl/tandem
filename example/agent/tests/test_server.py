import httpx


def test_health(agent_url: str) -> None:
    assert httpx.get(f"{agent_url}/health").json() == {"status": "ok"}
