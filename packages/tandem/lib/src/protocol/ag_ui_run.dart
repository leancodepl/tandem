import 'dart:async';

import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/chunk_events.dart';

/// Reads the decoded events of a response as the run that [input] requested,
/// for an `AgentConnection` over any transport:
/// `events.transform(agUiRun(input))`. Give it only the frames of this run's
/// request, and end the stream when the transport says the request is over.
///
/// Skips the runs a response replays before the `RUN_STARTED` that repeats
/// the `threadId` and `runId` of [input]. If a delta depends on a snapshot
/// from replay, send a `STATE_SNAPSHOT` inside the requested run first. A
/// `RUN_ERROR` before any `RUN_STARTED` still passes, unless it names another
/// run or thread. Expands text and tool-call chunks.
///
/// Fails with a [FormatException] on an ambiguous chunk, on a response that
/// ends before the requested `RUN_STARTED`, and on a run mixed into the
/// requested one: another `RUN_STARTED`, or an event that names another
/// thread. It does not check the `runId` of `RUN_FINISHED`, which some
/// servers replace during a run. An id-less `RUN_ERROR` or a terminal event
/// of an earlier run looks like this run's, so keeping those out is the
/// connection's job.
///
/// Tandem closes the stream at the first `RUN_FINISHED` or `RUN_ERROR` it
/// passes through and cancels the source subscription, even though
/// [AG-UI allows a later error](https://docs.ag-ui.com/spec/1.0/events/lifecycle#after-a-run-closes).
/// [Wire rules](https://github.com/leancodepl/tandem/blob/main/doc/design.md#wire-rules).
StreamTransformer<JsonObject, JsonObject> agUiRun(JsonObject input) =>
    StreamTransformer(
      (events, cancelOnError) => events
          .transform(_requestedRun(input))
          .expand(ChunkExpander().call)
          .listen(null, cancelOnError: cancelOnError),
    );

// Closing the sink cancels a response the server may leave open.
StreamTransformer<JsonObject, JsonObject> _requestedRun(JsonObject input) {
  final run = _RequestedRun(input);
  var sourceFailed = false;

  return StreamTransformer.fromHandlers(
    handleData: (event, sink) {
      switch (run.read(event)) {
        case _Step.skip:
          break;
        case _Step.pass:
          sink.add(event);
        case _Step.end:
          sink
            ..add(event)
            ..close();
        case _Step.mixed:
          sink
            ..addError(run.mixedError(event))
            ..close();
      }
    },
    handleError: (error, stackTrace, sink) {
      sourceFailed = true;
      sink.addError(error, stackTrace);
    },
    handleDone: (sink) {
      if (run.missingStart case final error? when !sourceFailed) {
        sink.addError(error);
      }
      sink.close();
    },
  );
}

/// What the requested run does with one event of a response.
enum _Step() {
  skip,
  pass,
  end,
  mixed,
}

/// Tells the events of the run that [_input] requested from those of the
/// other runs in a response.
final class _RequestedRun(final JsonObject _input) {
  var _started = false;
  var _ended = false;

  /// The runs the response started before the requested one.
  final _otherRuns = <String>[];

  bool get _filters => _input[AgUiFields.runId] is String;

  _Step read(JsonObject event) {
    final type = event[AgUiFields.type];
    if (!_filters) {
      return _passOrEnd(type);
    }
    if (_started) {
      // Only RUN_STARTED is checked for its runId: ag-ui-langgraph in
      // TypeScript ends a run with LangGraph's own runId (https://github.com/ag-ui-protocol/ag-ui/blob/dbfbddb7b3b898dc120b90610c941173b982757f/integrations/langgraph/typescript/src/agent.ts#L1189).
      final mixesRuns =
          type == AgUiEventTypes.runStarted ||
          _namesOther(event, AgUiFields.threadId);

      return mixesRuns ? _Step.mixed : _passOrEnd(type);
    }
    if (type == AgUiEventTypes.runStarted) {
      if (_isRequestedStart(event)) {
        _started = true;
        return _Step.pass;
      }
      _otherRuns.add(_describe(event));
      return _Step.skip;
    }
    final opensWithError =
        _otherRuns.isEmpty &&
        type == AgUiEventTypes.runError &&
        !_namesOther(event, AgUiFields.runId) &&
        !_namesOther(event, AgUiFields.threadId);

    return opensWithError ? _passOrEnd(type) : _Step.skip;
  }

  /// The error of a response that ended without starting the requested run.
  FormatException? get missingStart {
    if (!_filters || _started || _ended) {
      return null;
    }

    final shown = _otherRuns.take(3).join(', ');
    final more = _otherRuns.length > 3
        ? ' and ${_otherRuns.length - 3} more'
        : '';
    final started = _otherRuns.isEmpty
        ? 'It started no run.'
        : 'It started only $shown$more.';
    return FormatException(
      'The response ended before the RUN_STARTED of ${_describe(_input)}. '
      "$started Check that the server repeats the input's threadId and runId "
      'in RUN_STARTED.',
    );
  }

  /// The error of an event that does not belong to the requested run.
  FormatException mixedError(JsonObject event) {
    if (_isRequestedStart(event)) {
      return FormatException(
        'The response started ${_describe(_input)} twice. Deduplicate a '
        'resumed stream before agUiRun.',
      );
    }

    return FormatException(
      'The response mixed ${event[AgUiFields.type]} of ${_describe(event)} '
      "into ${_describe(_input)}. Pass agUiRun only the frames of this run's "
      'request.',
    );
  }

  _Step _passOrEnd(Object? type) {
    if (type case AgUiEventTypes.runFinished || AgUiEventTypes.runError) {
      _ended = true;
      return _Step.end;
    }

    return _Step.pass;
  }

  bool _isRequestedStart(JsonObject event) =>
      event[AgUiFields.runId] == _input[AgUiFields.runId] &&
      event[AgUiFields.threadId] == _input[AgUiFields.threadId];

  /// Whether [event] gives a [field] that differs from the input's.
  bool _namesOther(JsonObject event, String field) =>
      event[field] != null && event[field] != _input[field];
}

String _describe(JsonObject ids) =>
    switch ((ids[AgUiFields.runId], ids[AgUiFields.threadId])) {
      (null, null) => 'a run without IDs',
      (final runId, final threadId) => 'run $runId of thread $threadId',
    };
