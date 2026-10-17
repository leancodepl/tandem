# tandem

The core of Tandem, which lets an AI agent work on an existing Flutter screen together with the user over AG-UI. It has the agent list, the session, `TandemChat` and `ScriptedAgent`, and does not depend on bloc.

Apps depend on [`tandem_bloc`](https://pub.dev/packages/tandem_bloc), which exports this package. See the [main README](https://github.com/leancodepl/tandem#readme) for how to use it.

## AI

Tandem is written with AI assistance and reviewed by hand, except the AG-UI protocol layer in `lib/src/protocol/`, which has not had a full human review yet.
