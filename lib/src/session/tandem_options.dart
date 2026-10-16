/// Everything optional about a session, with defaults that fit a common
/// screen.
final class TandemOptions {
  /// Creates options.
  const TandemOptions({
    this.toolLabels = const {},
    this.maxAutoRuns = 5,
    this.reportUserEdits = true,
    this.context = const {},
    this.threadId,
    this.onDiagnostic,
  });

  /// Timeline labels for agent tools, which the app does not declare, such
  /// as `{'find_customer': 'Looking up the customer'}`. Without a label the
  /// timeline shows the tool's name in words.
  final Map<String, String> toolLabels;

  /// The loop guard: how many automatic follow-up runs in a row the agent
  /// may trigger by calling tools alone.
  ///
  /// Sending a message, approving and rejecting reset the count. When the
  /// agent goes over it, no run starts and the view shows a
  /// `TandemErrorKind.loopGuard` error.
  final int maxAutoRuns;

  /// Whether every run tells the agent which shared-state fields the user
  /// changed by hand since the previous run, so the agent notices a changed
  /// quantity and recalculates.
  final bool reportUserEdits;

  /// Extra context sent with every run, description to value, such as
  /// `{'locale': 'pl-PL', 'today': '2026-10-16'}`.
  final Map<String, String> context;

  /// The AG-UI thread id to use instead of a generated UUID.
  ///
  /// The history is not restored; use it only when the backend keeps the
  /// session.
  final String? threadId;

  /// Receives what the session ignored so the run could go on: unknown
  /// events, patches that failed, agent state the codec could not decode,
  /// results that could not be encoded. Defaults to `dart:developer`'s `log`
  /// with the name `tandem`.
  final void Function(TandemDiagnostic diagnostic)? onDiagnostic;
}

/// Something the session ignored so the run could go on: an unknown event, a
/// patch that failed, a decode error, a result that could not be encoded.
final class TandemDiagnostic {
  /// Creates a diagnostic. The session creates them.
  const TandemDiagnostic(this.message, {this.detail});

  /// What happened.
  final String message;

  /// The event, patch or exception involved, when there is one.
  final Object? detail;

  @override
  String toString() => detail == null
      ? 'TandemDiagnostic: $message'
      : 'TandemDiagnostic: $message ($detail)';
}
