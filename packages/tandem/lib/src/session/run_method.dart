import 'dart:convert';

import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/session/tandem_event.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';

/// The agent's answer and, when the method returned, the event `onEvent`
/// hears.
typedef MethodOutcome = ({ToolAnswer answer, AgentCall? returned});

/// Runs the method behind [call]. Never throws: a refused call is refused,
/// and any other error is reported and answered as failed, or as
/// result_unavailable when only encoding the result failed.
Future<MethodOutcome> runMethod(
  AgentListing listing,
  ToolCall call, {
  required void Function(Object error, StackTrace stack) report,
}) async {
  try {
    final arguments = jsonDecode(call.argumentsJson) as Map<String, Object?>;
    final result = await listing.call(
      call.tool,
      arguments,
      approved: call.approved,
    );
    final returned = AgentCall(
      tool: call.tool,
      arguments: arguments,
      result: result,
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
