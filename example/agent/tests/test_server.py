import httpx

LOCAL_ORIGIN = "http://localhost:57000"


def test_health(agent_url: str) -> None:
    assert httpx.get(f"{agent_url}/health").json() == {"status": "ok"}


def test_a_browser_app_on_localhost_may_post_to_the_agent(agent_url: str) -> None:
    def preflight(origin: str) -> httpx.Response:
        headers = {"Origin": origin, "Access-Control-Request-Method": "POST"}
        return httpx.options(f"{agent_url}/agent", headers=headers)

    assert preflight(LOCAL_ORIGIN).headers["access-control-allow-origin"] == LOCAL_ORIGIN
    assert "access-control-allow-origin" not in preflight("https://example.com").headers
