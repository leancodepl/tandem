import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/session/caller.dart';
import 'package:tandem/src/session/tandem_event.dart';
import 'package:tandem/src/session/tool_answer.dart';

/// The agent's answer and, when the method returned, the event `onEvent`
/// hears.
typedef MethodOutcome = ({ToolAnswer answer, AgentCall? returned});

/// Runs the method behind [tool] with the [arguments] of [caller], whose
/// paths point at values of [listing] unless they are frozen. Never throws: a refused call is refused, and any other
/// error is reported and answered as failed, or as result_unavailable when
/// only encoding the result failed.
Future<MethodOutcome> runMethod(
  AgentListing listing,
  String tool,
  CallArguments arguments, {
  required Caller caller,
  required bool approved,
  required void Function(Object error, StackTrace stack) report,
}) async {
  try {
    final (:result, arguments: read) = await listing.run(
      tool,
      arguments,
      approved: approved,
    );
    final returned = AgentCall(
      tool: tool,
      arguments: read,
      result: result,
      caller: caller,
    );
    try {
      return (answer: ToolAnswer.returned(result), returned: returned);
    } catch (err, st) {
      report(err, st);
      return (answer: ToolAnswer.resultUnavailable, returned: returned);
    }
  } on ToolCallRefused catch (refusal) {
    return (answer: ToolAnswer.refused(refusal.message), returned: null);
  } catch (err, st) {
    report(err, st);
    return (answer: ToolAnswer.failed, returned: null);
  }
}
