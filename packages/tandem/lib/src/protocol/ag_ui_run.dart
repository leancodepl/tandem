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
          .transform(_requestedRun(input))
          .expand(ChunkExpander().call)
          .listen(null, cancelOnError: cancelOnError),
    );

StreamTransformer<JsonObject, JsonObject> _requestedRun(JsonObject input) {
  final response = _Response(input);
  var sourceFailed = false;

  return StreamTransformer.fromHandlers(
    handleData: (event, sink) {
      switch (response.place(event)) {
        case .beforeTheRun:
          break;
        case .inTheRun:
          sink.add(event);
        case .endOfTheRun:
          // Closing the sink cancels a response the server may leave open.
          sink
            ..add(event)
            ..close();
        case .secondStart:
          sink
            ..addError(_startedTwice(input))
            ..close();
        case .inAnotherRun:
          sink
            ..addError(_mixedIn(event, into: input))
            ..close();
      }
    },
    handleError: (error, stackTrace, sink) {
      sourceFailed = true;
      sink.addError(error, stackTrace);
    },
    handleDone: (sink) {
      // A source that failed has already said why the run is missing.
      if (response.endedBeforeTheRun && !sourceFailed) {
        sink.addError(_missingRun(input, afterRuns: response.replayedRuns));
      }
      sink.close();
    },
  );
}

/// Where an event of a response belongs.
enum _Place() {
  /// In a run the server replays, or anywhere else before the requested run.
  beforeTheRun,
  inTheRun,

  /// The `RUN_FINISHED` or `RUN_ERROR` of the requested run.
  endOfTheRun,

  /// The requested `RUN_STARTED` again, as a resumed stream sends it.
  secondStart,
  inAnotherRun,
}

enum _Phase() {
  beforeTheRun,
  inTheRun,
  afterTheRun,
}

/// Follows the response to one request and places each of its events.
final class _Response(final JsonObject _request) {
  var _phase = _Phase.beforeTheRun;

  /// The runs the response started before the requested one, as the error
  /// of a response that never starts it names them.
  final replayedRuns = <String>[];

  bool get endedBeforeTheRun => _looksForTheRun && _phase == .beforeTheRun;

  _Place place(JsonObject event) {
    if (!_looksForTheRun) {
      return _endsARun(event) ? .endOfTheRun : .inTheRun;
    }

    return switch (_phase) {
      .beforeTheRun => _placeBeforeTheRun(event),
      .inTheRun => _placeInTheRun(event),
      .afterTheRun => .inAnotherRun,
    };
  }

  _Place _placeBeforeTheRun(JsonObject event) {
    if (_startsTheRun(event)) {
      _phase = .inTheRun;
      return .inTheRun;
    }
    if (_failsTheRun(event)) {
      _phase = .afterTheRun;
      return .endOfTheRun;
    }

    if (_startsARun(event)) {
      replayedRuns.add(_describe(event));
    }
    return .beforeTheRun;
  }

  _Place _placeInTheRun(JsonObject event) {
    if (_startsTheRun(event)) return .secondStart;
    if (_startsARun(event) || _namesAnotherThread(event)) return .inAnotherRun;
    if (_endsARun(event)) {
      _phase = .afterTheRun;
      return .endOfTheRun;
    }

    return .inTheRun;
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
        runId == null && replayedRuns.isEmpty;
  }

  bool _namesAnotherThread(JsonObject event) =>
      event[AgUiFields.threadId] != null &&
      event[AgUiFields.threadId] != _request[AgUiFields.threadId];
}

bool _startsARun(JsonObject event) =>
    event[AgUiFields.type] == AgUiEventTypes.runStarted;

// The runId of RUN_FINISHED is not checked: ag-ui-langgraph in TypeScript
// ends a run with LangGraph's own (https://github.com/ag-ui-protocol/ag-ui/blob/dbfbddb7b3b898dc120b90610c941173b982757f/integrations/langgraph/typescript/src/agent.ts#L1189).
bool _endsARun(JsonObject event) => switch (event[AgUiFields.type]) {
  AgUiEventTypes.runFinished || AgUiEventTypes.runError => true,
  _ => false,
};

FormatException _missingRun(
  JsonObject input, {
  required List<String> afterRuns,
}) {
  const namedAtMost = 3;
  final named = afterRuns.take(namedAtMost).join(', ');
  final more = afterRuns.length > namedAtMost
      ? ' and ${afterRuns.length - namedAtMost} more'
      : '';
  final started = afterRuns.isEmpty
      ? 'It started no run.'
      : 'It started only $named$more.';
  return FormatException(
    'The response ended before the RUN_STARTED of ${_describe(input)}. '
    "$started Check that the server repeats the input's threadId and runId "
    'in RUN_STARTED.',
  );
}

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
