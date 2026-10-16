import 'package:meta/meta.dart';

/// Why the last run failed. Shown in the view until the next run starts.
@immutable
final class TandemError {
  /// Creates the error. The session creates them; public for widget tests.
  const TandemError({
    required this.kind,
    required this.message,
    required Future<void> Function() onRetry,
    this.code,
  }) : _onRetry = onRetry;

  /// Where it failed.
  final TandemErrorKind kind;

  /// What happened, for logs and developers; not localized.
  final String message;

  /// The agent's `RUN_ERROR` code, when it sent one.
  final String? code;

  final Future<void> Function() _onRetry;

  /// Sends everything not yet delivered (tool results, queued messages)
  /// in a new run, without a new user message.
  ///
  /// Safe to repeat: the agent backend skips messages it already processed.
  /// That also means a retry cannot bring back an answer that was lost: when
  /// the connection broke after the agent had received the request, the
  /// backend may answer the retry with nothing (ag-ui-adk does). The view
  /// then shows an error saying so, and a new message goes on from there.
  Future<void> retry() => _onRetry();

  @override
  String toString() => code == null
      ? 'TandemError(${kind.name}): $message'
      : 'TandemError(${kind.name}, $code): $message';
}

/// The kind of a [TandemError].
enum TandemErrorKind {
  /// The request failed or the stream broke: a status other than 2xx, a
  /// 2xx answer that is not an event stream (usually a wrong URL), an idle
  /// timeout, a socket or stream error.
  connection,

  /// The agent backend reported `RUN_ERROR`.
  agent,

  /// The agent kept calling tools in automatic follow-up runs, and the
  /// session stopped after `TandemOptions.maxAutoRuns` in a row. The results
  /// wait for the next message or [TandemError.retry].
  loopGuard,
}
