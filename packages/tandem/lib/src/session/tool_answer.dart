import 'dart:convert';

/// The `content` of the tool message that answers a call. A call that did not
/// return says so here too, because ag-ui-adk ignores a tool message's
/// `error` and the model reads an empty content as success.
extension type const ToolAnswer._(String json) implements String {
  new returned(Object? result) : this._(jsonEncode(result));

  /// The method did not run, or threw for the agent's bad input.
  new refused(String reason)
    : this._(jsonEncode({'status': 'refused', 'reason': reason}));

  /// The method threw [error], which is a bug of the app.
  new failed(Object error)
    : this._(jsonEncode({'status': 'failed', 'error': '$error'}));

  /// Not a bare `rejected`: Gemini reads that as the system refusing the call.
  static const rejected = ToolAnswer._('{"status":"rejected_by_user"}');

  /// The call did not run: its run was stopped or failed, or the user wrote
  /// instead of deciding.
  static const cancelled = ToolAnswer._('{"status":"cancelled"}');
  static const invalidated = ToolAnswer._('{"status":"invalidated"}');
}
