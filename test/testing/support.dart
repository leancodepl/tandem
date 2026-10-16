import 'package:tandem/protocol.dart';
import 'package:tandem/testing.dart';

/// The thread id the tests use unless they test thread ids.
const threadId = 'thread-1';

/// The first user message of most tests.
const firstUserMessage = WireUserMessage('user-1', 'Order 40 HDMI cables');

/// A request as the session would build it.
RunInput runInput(
  String runId, {
  List<WireMessage> messages = const [firstUserMessage],
  List<WireTool> tools = const [],
  Map<String, Object?> state = const {},
  List<WireContext> context = const [],
  String thread = threadId,
}) => RunInput(
  threadId: thread,
  runId: runId,
  messages: messages,
  tools: tools,
  state: state,
  context: context,
);

/// A declaration of one of the app's tools.
WireTool appTool(String name) => WireTool(
  name: name,
  description: 'The $name tool of the app.',
  parameters: const {'type': 'object', 'properties': <String, Object?>{}},
);

/// Plays one whole run.
Future<List<WireEvent>> play(ScriptedAgent agent, RunInput input) =>
    agent.run(input).toList();

/// The wire types of [events].
List<String> typesOf(Iterable<WireEvent> events) => [
  for (final event in events) event.type,
];

/// The id of the only call of [toolName] in [events].
String callIdOf(Iterable<WireEvent> events, String toolName) => events
    .whereType<ToolCallStart>()
    .singleWhere((event) => event.toolCallName == toolName)
    .toolCallId;

/// An answer of the app to the tool call [toolCallId].
WireToolMessage answer(String toolCallId, {String id = '', String? content}) =>
    WireToolMessage(
      id.isEmpty ? 'tool-$toolCallId' : id,
      toolCallId: toolCallId,
      content: content ?? '{"status":"ok","result":null}',
    );

/// The history after a run that started from [before] and received
/// [events], built the way Tandem builds it: a text message keeps its id, a
/// tool call goes into its parent message or into `asst-<toolCallId>`, and a
/// `TOOL_CALL_RESULT` becomes a tool message with the event's `messageId`.
List<WireMessage> historyAfter(
  List<WireMessage> before,
  Iterable<WireEvent> events,
) {
  final messages = [...before];
  final texts = <String, StringBuffer>{};
  final calls = <String, ({String name, String? parent, StringBuffer args})>{};
  for (final event in events) {
    switch (event) {
      case TextStart(:final messageId):
        texts[messageId] = StringBuffer();
      case TextContent(:final messageId, :final delta):
        texts[messageId]?.write(delta);
      case TextEnd(:final messageId):
        messages.add(
          WireAssistantMessage(
            messageId,
            content: '${texts.remove(messageId)}',
          ),
        );
      case ToolCallStart(:final toolCallId, :final toolCallName):
        calls[toolCallId] = (
          name: toolCallName,
          parent: event.parentMessageId,
          args: StringBuffer(),
        );
      case ToolCallArgs(:final toolCallId, :final delta):
        calls[toolCallId]?.args.write(delta);
      case ToolCallEnd(:final toolCallId):
        if (calls.remove(toolCallId) case final call?) {
          _addCall(
            messages,
            call.parent ?? 'asst-$toolCallId',
            WireToolCall(
              id: toolCallId,
              name: call.name,
              arguments: call.args.isEmpty ? '{}' : '${call.args}',
            ),
          );
        }
      case ToolCallResult(:final messageId, :final toolCallId, :final content):
        messages.add(
          WireToolMessage(messageId, toolCallId: toolCallId, content: content),
        );
      default:
        break;
    }
  }
  return messages;
}

void _addCall(List<WireMessage> messages, String hostId, WireToolCall call) {
  final index = messages.indexWhere((message) => message.id == hostId);
  final host = index == -1 ? null : messages[index];
  if (host is WireAssistantMessage) {
    messages[index] = WireAssistantMessage(
      hostId,
      content: host.content,
      toolCalls: [...host.toolCalls, call],
    );
  } else {
    messages.add(WireAssistantMessage(hostId, toolCalls: [call]));
  }
}
