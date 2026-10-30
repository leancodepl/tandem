# Waypoint

Waypoint is a business travel app built on Tandem: the showcase of the repository. It uses Tandem the way a product would, while [example](../example) keeps small examples to copy from.

Ola travels to her clients, and Waypoint keeps her trips, reads the e-mails she forwards to it and books changes once she approves. Its assistant is not a separate chat: it works in each screen, through that screen's methods.

- **Trips** (`lib/features/trips`) lists Ola's trips and, on top, the forwarded e-mails that change one of them or ask for a new one.
- **Trip** (`lib/features/trip`) shows a trip day by day with its assistant beside it on an iPad and under it on a phone. When an e-mail moved a meeting, the screen notes it for the agent (`session.note`) and wakes it (`session.wake`): the agent fits the hotel and the flight home around the change and asks to book them. Booking waits for Ola's approval, and a change she makes voids the request, which the app then asks again on its own.
- **Inbox** (`lib/features/inbox`) holds the forwarded e-mails, each with its trip. A hotel's confirmation fills in the booking form (`lib/features/booking`) without a chat.
- **Plan a trip** (`lib/features/plan_trip`) turns an invitation, or what Ola writes, into a new trip. The agent fills in the form with the app's `find_flights` and `find_hotels` and chooses within the company policy (`packages/waypoint_travel`), which the app's methods enforce: they refuse a choice outside it, with the reason. Ola books the trip with her own tap.
- **Arrival day** (`lib/features/arrival`) opens from the trip. The agent draws the day with `tandem_show_view` and Waypoint's own widgets, listed in `ArrivalCatalog` with `@TandemCatalog`: the first meeting, the ways from the airport, the host and the hotel. The view's buttons call the screen's methods with the same approvals and refusals as the agent's calls, so the policy that rules out a taxi shows on the view, and booking the S-Bahn waits for Ola's approval.
- **Expenses** (`lib/features/expenses`) holds the reports of past trips. When a report opens, the agent adds the trip's forwarded receipts. A meal over the daily limit is refused with what is left for that day, and the agent claims that much. It then asks to submit the report, and the request shows in the screen's own bar, not in a chat.
- [agent](agent) is the agent behind it, on Google ADK and Gemini.
- [waypoint_scripted_agent](packages/waypoint_scripted_agent) plays the agents as scripts in the app, for a run without a key.
- [waypoint_travel](packages/waypoint_travel) stands in for the travel provider: the trips, the forwarded e-mails, the policy and the searches, in memory.
- [waypoint_design_system](packages/waypoint_design_system) is Waypoint's look: its colours, fonts and shared widgets.

The demo's today is Saturday, 24 October 2026. Ola's receipts from Paris in September wait for their report, on Wednesday she flies to Berlin for a workshop that Studio Kraft has just moved to Friday, in November she pitches in Copenhagen, and Alpenlicht has just invited her to Vienna in December.

## Run

The same app runs in two ways. One switch tells them apart.

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
