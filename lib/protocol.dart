/// Tandem's own model of the AG-UI wire format, for authors of
/// `AgentConnection` adapters. Screens and their tests never need it.
///
/// AG-UI is an open protocol between an app and an agent backend: the app
/// POSTs a `RunInput` and the backend streams `WireEvent`s back. An adapter
/// sends `RunInput.toJson` and decodes every event with
/// `WireEvent.fromJson`, which never throws.
library;

export 'src/protocol/wire/events.dart'
    show
        MessagesSnapshot,
        RunError,
        RunFinished,
        RunStarted,
        StateDelta,
        StateSnapshot,
        TextChunk,
        TextContent,
        TextEnd,
        TextStart,
        ToolCallArgs,
        ToolCallChunk,
        ToolCallEnd,
        ToolCallResult,
        ToolCallStart,
        UnknownEvent,
        WireEvent;
export 'src/protocol/wire/messages.dart'
    show
        WireAssistantMessage,
        WireMessage,
        WireToolCall,
        WireToolMessage,
        WireUserMessage;
export 'src/protocol/wire/run_input.dart' show RunInput, WireContext, WireTool;
