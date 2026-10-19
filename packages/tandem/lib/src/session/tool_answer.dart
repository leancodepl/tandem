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

  /// The call did not run: its run was stopped or failed, the user wrote
  /// instead of deciding, or an earlier request of its turn was rejected.
  static const cancelled = ToolAnswer._('{"status":"cancelled"}');
  static const invalidated = ToolAnswer._(
    '{"status":"invalidated","reason":"What you see changed after you asked, '
    'so this call did not run. Do not repeat calls that already returned. '
    'Read the current context and ask again only if this call still fits."}',
  );
}
