import 'dart:convert';

import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/session/agent_call.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';

/// The agent's answer and, when the method returned, what `onAgentCall`
/// hears.
typedef MethodOutcome = ({ToolAnswer answer, AgentCall? returned});

/// Runs the method behind [call]. Never throws: a refused call and the
/// agent's bad input are refused, and any other error is reported and
/// answered as failed.
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
    return (
      answer: ToolAnswer.returned(result),
      returned: AgentCall(
        tool: call.tool,
        arguments: arguments,
        result: result,
      ),
    );
  } on ToolCallRefused catch (refusal) {
    return (answer: ToolAnswer.refused(refusal.message), returned: null);
  } catch (err, st) {
    // The agent's bad input. A RangeError is a bug, so it is reported.
    if (err is ArgumentError && err is! RangeError) {
      return (answer: ToolAnswer.refused('$err'), returned: null);
    }
    report(err, st);
    return (answer: ToolAnswer.failed(err), returned: null);
  }
}
