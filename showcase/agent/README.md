# Waypoint agent

The agent behind Waypoint ([../README.md](../README.md)), on [Google ADK](https://google.github.io/adk-docs/) with [ag-ui-adk](https://pypi.org/project/ag-ui-adk/). `POST /agent` serves the trip, `POST /agent/booking` the booking form, `POST /agent/plan` a new trip, `POST /agent/expenses` an expense report and `POST /agent/arrival` the arrival day, each with its own instruction ([trip.txt](src/waypoint_agent/trip.txt), [booking.txt](src/waypoint_agent/booking.txt), [plan.txt](src/waypoint_agent/plan.txt), [expenses.txt](src/waypoint_agent/expenses.txt), [arrival.txt](src/waypoint_agent/arrival.txt)). All its tools are the app's: the screen reaches the model as the AG-UI `context` of each run, and the app's methods as the run's `tools`. Gemini's turns stream through [adk-streaming](../../example/agents/adk-streaming), which the order desk agent on ADK uses too.

Needs [uv](https://docs.astral.sh/uv/).

## Run

With Gemini, after copying `.env.example` to `.env` and setting `GOOGLE_API_KEY` in it:

```sh
uv run waypoint-agent
```

With the scripted model, which plays the demo without a model and without an API key:

```sh
WAYPOINT_FAKE_LLM=1 uv run waypoint-agent
```

The server listens on `127.0.0.1:8010`. Threads live in memory, so a restart forgets them.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `WAYPOINT_FAKE_LLM` | | `1` swaps in the scripted model. |
| `WAYPOINT_MODEL` | `gemini-3.8-flash` | The Gemini model. |
| `WAYPOINT_THINKING` | `low` | `minimal`, `low`, `medium` or `high`. |
| `WAYPOINT_TODAY` | `2026-10-24` | The demo's today, in the week of the trip. |
| `WAYPOINT_HOST` | `127.0.0.1` | The address to listen on. Only a physical device needs `0.0.0.0`, which lets anyone on your network spend your API key. |
| `WAYPOINT_PORT` | `8010` | The port to listen on. |
| `GOOGLE_API_KEY` | | The Gemini API key, also read from `.env`. |

## Checks

```sh
uv sync --locked
uv run ruff check .
uv run ruff format --check .
uv run pytest
```
