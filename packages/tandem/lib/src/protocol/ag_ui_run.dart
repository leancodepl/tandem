import 'dart:async';

import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/chunk_events.dart';

/// Reads the decoded events of one request as the run that [input] asked
/// for, for an `AgentConnection` over any transport:
/// `events.transform(agUiRun(input))`.
///
/// It skips the runs the server replays first, expands text and tool-call
/// chunks, and closes at the run's `RUN_FINISHED` or `RUN_ERROR`, which
/// cancels the source.
///
/// The connection does the rest:
/// - It passes only the frames of this run's request, and ends the stream
///   when the transport says the request is over.
/// - It passes an [input] with the `threadId` and `runId` that the server
///   repeats in `RUN_STARTED`. Without a `runId`, every event is the run's.
/// - It keeps out what looks like this run's and is not: the repeats of a
///   resumed stream, and an id-less `RUN_ERROR` or end of an earlier run.
///
/// The stream fails with a [FormatException] and closes when the response
/// ends before the requested `RUN_STARTED`, or when another `RUN_STARTED` or
/// an event of another thread comes inside the run. An ambiguous chunk fails
/// it too, and the stream goes on.
///
/// Every case is in the
/// [wire rules](https://github.com/leancodepl/tandem/blob/main/doc/design.md#wire-rules).
StreamTransformer<JsonObject, JsonObject> agUiRun(JsonObject input) =>
    StreamTransformer(
      (events, cancelOnError) => events
          .transform(_RequestedRun(input).events)
          .expand(ChunkExpander().call)
          .listen(null, cancelOnError: cancelOnError),
    );

/// Selects one run per subscription. Closing the sink also cancels a response
/// the server may leave open.
final class _RequestedRun(final JsonObject _request) {
  final _replayedRuns = <String>[];
  var _waitingForStart = true;
  var _receivedEvent = false;
  var _sourceFailed = false;

  StreamTransformer<JsonObject, JsonObject> get events =>
      StreamTransformer.fromHandlers(
        handleData: _receive,
        handleError: (error, stack, sink) {
          _sourceFailed = true;
          sink.addError(error, stack);
        },
        handleDone: (sink) {
          if (_looksForTheRun && _waitingForStart && !_sourceFailed) {
            sink.addError(_missingRun());
          }
          sink.close();
        },
      );

  void _receive(JsonObject event, EventSink<JsonObject> sink) {
    _receivedEvent = true;
    if (_looksForTheRun) {
      if (_waitingForStart) {
        if (_startsTheRun(event) || _failsTheRun(event)) {
          _waitingForStart = false;
        } else {
          if (_startsARun(event)) _replayedRuns.add(_describe(event));
          return;
        }
      } else if (_startsARun(event) || _namesAnotherThread(event)) {
        final error = _startsTheRun(event)
            ? _startedTwice(_request)
            : _mixedIn(event, into: _request);
        sink
          ..addError(error)
          ..close();
        return;
      }
    }
    sink.add(event);
    if (_endsARun(event)) sink.close();
  }

  /// An input without a `runId` names no run to look for.
  bool get _looksForTheRun => _request[AgUiFields.runId] is String;

  bool _startsTheRun(JsonObject event) =>
      _startsARun(event) &&
      event[AgUiFields.runId] == _request[AgUiFields.runId] &&
      event[AgUiFields.threadId] == _request[AgUiFields.threadId];

  /// Whether [event] is the `RUN_ERROR` of the requested run, which then
  /// never started. AG-UI gives `RUN_ERROR` no ids, so one without them
  /// counts only while no replayed run could own it.
  bool _failsTheRun(JsonObject event) {
    if (event[AgUiFields.type] != AgUiEventTypes.runError) return false;
    if (_namesAnotherThread(event)) return false;

    final runId = event[AgUiFields.runId];
    return runId == _request[AgUiFields.runId] ||
        runId == null && _replayedRuns.isEmpty;
  }

  bool _namesAnotherThread(JsonObject event) =>
      event[AgUiFields.threadId] != null &&
      event[AgUiFields.threadId] != _request[AgUiFields.threadId];

  FormatException _missingRun() {
    final missing =
        'The response ended before the RUN_STARTED of ${_describe(_request)}.';
    if (!_receivedEvent) {
      return FormatException(
        '$missing It had no AG-UI event. Check that the endpoint serves AG-UI.',
      );
    }

    if (_replayedRuns.isEmpty) {
      return FormatException('$missing It started no run.');
    }

    const namedAtMost = 3;
    final named = _replayedRuns.take(namedAtMost).join(', ');
    final more = _replayedRuns.length > namedAtMost
        ? ' and ${_replayedRuns.length - namedAtMost} more'
        : '';
    return FormatException(
      '$missing It started only $named$more. Check that the server repeats '
      "the input's threadId and runId in RUN_STARTED.",
    );
  }
}

bool _startsARun(JsonObject event) =>
    event[AgUiFields.type] == AgUiEventTypes.runStarted;

// The runId of RUN_FINISHED is not checked: ag-ui-langgraph in TypeScript
// ends a run with LangGraph's own (https://github.com/ag-ui-protocol/ag-ui/blob/dbfbddb7b3b898dc120b90610c941173b982757f/integrations/langgraph/typescript/src/agent.ts#L1189).
bool _endsARun(JsonObject event) => switch (event[AgUiFields.type]) {
  AgUiEventTypes.runFinished || AgUiEventTypes.runError => true,
  _ => false,
};

FormatException _startedTwice(JsonObject input) => FormatException(
  'The response started ${_describe(input)} twice. Deduplicate a resumed '
  'stream before agUiRun.',
);

FormatException _mixedIn(JsonObject event, {required JsonObject into}) =>
    FormatException(
      'The response mixed ${event[AgUiFields.type]} of ${_describe(event)} '
      "into ${_describe(into)}. Pass agUiRun only the frames of this run's "
      'request.',
    );

String _describe(JsonObject ids) =>
    switch ((ids[AgUiFields.runId], ids[AgUiFields.threadId])) {
      (null, null) => 'a run without IDs',
      (final runId, final threadId) => 'run $runId of thread $threadId',
    };
