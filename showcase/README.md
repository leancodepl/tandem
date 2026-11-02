# Waypoint

Waypoint is a business travel app built on Tandem: the showcase of the repository. It uses Tandem the way a product would, while [example](../example) keeps small examples to copy from.

Ola travels to her clients, and Waypoint keeps her trips, reads the e-mails she forwards to it and books changes once she approves. Its assistant is not a separate chat: it works in each screen, through that screen's methods.

- **Trips** (`lib/features/trips`) lists Ola's trips and, on top, the forwarded e-mails that change one of them or ask for a new one.
- **Trip** (`lib/features/trip`) shows a trip day by day with its assistant beside it on an iPad and under it on a phone. Forwarded e-mails are context for the assistant. Ola asks for the changes she wants, including a different date from the e-mail. Booking waits for her approval. Editing the trip voids an old request; Ola can ask the assistant to review it again.
- **Inbox** (`lib/features/inbox`) holds the forwarded e-mails, each with its trip. Ola opens a hotel's confirmation and chooses **Fill from email** in the booking form (`lib/features/booking`).
- **Plan a trip** (`lib/features/plan_trip`) lets Ola ask to plan from an invitation or from what she writes, then revise or remove meetings. Repeating the invitation keeps identical meetings once. The agent fills in the form with the app's `find_flights` and `find_hotels` and chooses within the company policy (`packages/waypoint_travel`), which the app's methods enforce: they refuse a choice outside it, with the reason. Ola books the trip with her own tap.
- **Arrival day** (`lib/features/arrival`) opens from the trip. Ola chooses **Plan my arrival** or writes a request. The agent draws the day with `tandem_show_view` and Waypoint's own widgets, listed in `ArrivalCatalog` with `@TandemCatalog`: the first meeting, the ways from the airport, the host and the hotel. The view's buttons call the screen's methods with the same approvals and refusals as the agent's calls, so the policy that rules out a taxi shows on the view, and booking the S-Bahn waits for Ola's approval.
- **Expenses** (`lib/features/expenses`) holds the reports of past trips. Ola chooses **Add forwarded receipts** to ask the agent to fill a report. A meal over the daily limit is refused with what is left for that day, and the agent claims that much. Ola checks the claims and submits the report with her own tap. An explicit request to the agent to submit waits for approval in the screen's own bar.
- [agent](agent) is the agent behind it, on Google ADK and Gemini.
- [waypoint_scripted_agent](packages/waypoint_scripted_agent) plays the agents as scripts in the app, for a run without a key.
- [waypoint_travel](packages/waypoint_travel) stands in for the travel provider: the trips, the forwarded e-mails, the policy and the searches, in memory.
- [waypoint_design_system](packages/waypoint_design_system) is Waypoint's look: its colours, fonts and shared widgets.

The demo's today is Saturday, 24 October 2026. Ola's receipts from Paris in September wait for their report, on Wednesday she flies to Berlin for a workshop that Studio Kraft has just moved to Friday, in November she pitches in Copenhagen, and Alpenlicht has just invited her to Vienna in December.

Travel dates use the Central European clock (`Europe/Warsaw`, CET/CEST), shared by these destinations. Inputs with UTC offsets are converted to that clock; inputs without offsets already use it. See the civil-time limits in [GLOSSARY.md](GLOSSARY.md).

## Run

Opening a screen does not run the assistant or change the trip or forms. The assistant starts with a message or a labelled action button.

The same app runs in two ways. The default connects to the agent over HTTP. With Gemini, the model chooses its tools from the traveller's request and the current screen; it has no scripted fallback. Travel searches and bookings use the in-memory demo provider.

Without a key, on scripts in place of the agent ([waypoint_scripted_agent](packages/waypoint_scripted_agent)). It needs no server:

```sh
cd app && fvm flutter run --dart-define=SCRIPTED=true
```

The scripts know the demo: the workshop in Berlin that moves to Friday, the hotels' confirmation e-mails, the invitation to Vienna, the receipts from Paris and the arrival day in Berlin.

With the agent, on Gemini or on its own scripted model ([agent/README.md](agent/README.md)). Start the agent, then the app:

```sh
cd agent && uv run waypoint-agent
```

```sh
cd app && fvm flutter run
```

Another endpoint than `http://localhost:8010/agent`, or `http://10.0.2.2:8010/agent` on an Android emulator: `--dart-define=AGENT=<url>`.

### macOS

Requires Xcode. The macOS runner is included, so no platform generation is needed.

Without a server or an API key:

```sh
cd app && fvm flutter run -d macos --dart-define=SCRIPTED=true
```

To try the HTTP connection without an API key, start the scripted backend:

```sh
cd agent && WAYPOINT_FAKE_LLM=1 uv run waypoint-agent
```

Then, in another terminal:

```sh
cd app && fvm flutter run -d macos
```

For Gemini, start the agent as described in [agent/README.md](agent/README.md) and use the same app command.
