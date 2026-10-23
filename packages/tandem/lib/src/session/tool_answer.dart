import 'dart:convert';

import 'package:tandem/src/protocol/ag_ui.dart';

/// What came of a call, as the `status` of its answer.
extension type const ToolStatus._(String value) implements String {
  static const returned = ToolStatus._('returned');

  /// The method did not run, or threw a `ToolCallRefused`.
  static const refused = ToolStatus._('refused');

  /// The method threw anything else. The error stays in the app's reports.
  static const failed = ToolStatus._('failed');

  /// The method returned, but `jsonEncode` failed on its result.
  static const resultUnavailable = ToolStatus._('result_unavailable');

  /// Not a bare `rejected`: Gemini reads that as the system refusing the call.
  static const rejectedByUser = ToolStatus._('rejected_by_user');

  /// The call did not run: its run was stopped or failed, the user wrote
  /// instead of deciding, or an earlier request of its turn was rejected.
  static const cancelled = ToolStatus._('cancelled');

  /// What the agent sees changed after it asked.
  static const invalidated = ToolStatus._('invalidated');
}

/// The answer to a call of a listed method: what the method returned, or why
/// it did not return.
sealed class const ToolAnswer() {
  /// Throws when JSON cannot encode [result].
  factory returned(Object? result) = _Returned;

  factory refused(String reason) => _NotReturned(.refused, {'reason': reason});

  static const failed = _NotReturned(.failed, {
    'error':
        'The method failed and may have changed the app. Do not retry '
        'automatically.',
  });

  static const resultUnavailable = _NotReturned(.resultUnavailable, {
    'reason':
        'The method returned; result encoding failed. Do not repeat the call.',
  });

  static const rejected = _NotReturned(.rejectedByUser);

  static const cancelled = _NotReturned(.cancelled);

  static const invalidated = _NotReturned(.invalidated, {
    'reason':
        'What you see changed after you asked, so this call did not run. Do '
        'not repeat calls that already returned. Read the current context and '
        'ask again only if this call still fits.',
  });

  ToolStatus get status;

  /// The answer with its `status`, as a coding agent gets it.
  JsonObject get json;

  /// The `content` of the tool message that answers the in-app agent. A call
  /// that did not return says so here too, because ag-ui-adk ignores a tool
  /// message's `error` and the model reads an empty content as success.
  String get content => jsonEncode(json);
}

final class _Returned(final Object? _result) extends ToolAnswer {
  @override
  final String content = jsonEncode(_result);

  @override
  ToolStatus get status => .returned;

  @override
  JsonObject get json => {'status': status, 'result': _result};
}

final class const _NotReturned(
  @override final ToolStatus status, [
  final JsonObject _details = const {},
]) extends ToolAnswer {
  @override
  JsonObject get json => {'status': status, ..._details};
}
