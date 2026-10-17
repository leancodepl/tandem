# Tandem example

An order desk for an iPad: an agent fills in a B2B order from a pasted e-mail, together with the
user, and places it once the user approves. The app is `lib/main.dart` and `lib/desk/`, with
`OrderDeskCubit` as the screen's cubit. Its agent is [`agent/`](agent), a Google ADK agent in
Python. `lib/order_cubit.dart` is the example of the package README, and the tests use
`lib/shopping_list.dart`.

## Run the agent

In `example/agent`, with [uv](https://docs.astral.sh/uv/). The scripted model needs no API key and
no network:

```sh
TANDEM_FAKE_LLM=1 uv run order-agent
```

For Gemini, copy `.env.example` to `.env`, set `GOOGLE_API_KEY` in it, and run:

```sh
uv run order-agent
```

The agent listens on `127.0.0.1:8000`. Gemini's turns go through
[`streaming.py`](agent/src/order_agent/streaming.py), which streams all calls of a turn in one
chunk: ag-ui-adk drops a second parallel call of the same tool when the calls come in separate
chunks.

## Run the app

In `example`, on an iPad simulator (the example has the iOS platform only):

```sh
fvm flutter run
```

The app talks to the agent at `http://localhost:8000/agent`, which a simulator reaches on the same
Mac. Paste this e-mail into the chat:

> Hi, could you send us 40 HDMI cables (2 m) and 12 of the 27-inch monitors like last time? Delivery to Magazynowa 5, Poznań by Friday please. Thanks, Marta, Acme Office Supply

The rest of the script is in [agent/README.md](agent/README.md).
`integration_test/demo_recording_test.dart` plays it against the running agent:

```sh
fvm flutter test integration_test/demo_recording_test.dart -d <iPad simulator>
```
