import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';

void main() {
  test('a connection over another transport reads only the requested run, '
      'with its chunks expanded, while the source stays open', () async {
    var sourceCancelled = false;
    final source = StreamController<Map<String, Object?>>(
      onCancel: () => sourceCancelled = true,
    );
    final run = source.stream
        .transform(agUiRun({'threadId': 'thread-A', 'runId': 'run-current'}))
        .toList();

    source
      ..add({
        'type': 'RUN_ERROR',
        'threadId': 'thread-A',
        'runId': 'run-old',
        'message': 'Old failure',
      })
      ..add({
        'type': 'RUN_ERROR',
        'threadId': 'thread-B',
        'runId': 'run-current',
        'message': 'Other thread',
      })
      ..add({'type': 'RUN_STARTED', 'threadId': 'thread-A', 'runId': 'run-old'})
      ..add({'type': 'TEXT_MESSAGE_CHUNK', 'messageId': 'm1', 'delta': 'Old.'})
      ..add({'type': 'MESSAGES_SNAPSHOT', 'messages': <Object?>[]})
      ..add({'type': 'RUN_ERROR', 'message': 'Old'})
      ..add({
        'type': 'RUN_STARTED',
        'threadId': 'thread-B',
        'runId': 'run-current',
      })
      ..add({'type': 'RUN_FINISHED'})
      ..add({
        'type': 'RUN_STARTED',
        'threadId': 'thread-A',
        'runId': 'run-current',
      })
      ..add({'type': 'TEXT_MESSAGE_CHUNK', 'messageId': 'm2', 'delta': 'New.'})
      ..add({
        'type': 'TOOL_CALL_CHUNK',
        'toolCallId': 'c2',
        'toolCallName': 'add',
        'delta': '{"item":"eggs"}',
      })
      ..add({'type': 'RUN_FINISHED'})
      ..add({
        'type': 'RUN_STARTED',
        'threadId': 'thread-A',
        'runId': 'run-next',
      });

    expect(await run, [
      {'type': 'RUN_STARTED', 'threadId': 'thread-A', 'runId': 'run-current'},
      {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm2', 'delta': 'New.'},
      {'type': 'TOOL_CALL_START', 'toolCallId': 'c2', 'toolCallName': 'add'},
      {
        'type': 'TOOL_CALL_ARGS',
        'toolCallId': 'c2',
        'delta': '{"item":"eggs"}',
      },
      {'type': 'RUN_FINISHED'},
    ]);
    expect(sourceCancelled, isTrue);
  });

  test('a RUN_FINISHED of the thread with another runId ends the requested '
      'run, as ag-ui-langgraph in TypeScript sends', () async {
    const input = {'threadId': 'thread-A', 'runId': 'run-current'};
    const start = {'type': 'RUN_STARTED', ...input};
    const finish = {
      'type': 'RUN_FINISHED',
      'threadId': 'thread-A',
      'runId': 'run-langgraph',
    };
    final run = Stream<Map<String, Object?>>.fromIterable([start, finish])
        .transform(agUiRun(input));

    expect(await run.toList(), [start, finish]);
  });

  test('a run mixed into the requested one fails it', () async {
    const input = {'threadId': 'thread-A', 'runId': 'run-current'};
    const start = {'type': 'RUN_STARTED', ...input};
    final otherStart = Stream<Map<String, Object?>>.fromIterable([
      start,
      {'type': 'RUN_STARTED', 'threadId': 'thread-A', 'runId': 'run-other'},
      {'type': 'TOOL_CALL_START', 'toolCallId': 'c1', 'toolCallName': 'add'},
      {'type': 'RUN_FINISHED', ...input},
    ]).transform(agUiRun(input));
    final otherThread = Stream<Map<String, Object?>>.fromIterable([
      start,
      {'type': 'RUN_FINISHED', 'threadId': 'thread-B', 'runId': 'run-current'},
    ]).transform(agUiRun(input));

    await expectLater(
      otherStart,
      emitsInOrder([start, emitsError(isFormatException), emitsDone]),
    );
    await expectLater(
      otherThread,
      emitsInOrder([start, emitsError(isFormatException), emitsDone]),
    );
  });

  test('before the requested run started, a RUN_ERROR ends it when it names '
      'the run, or names none and no run started', () async {
    const input = {'threadId': 'thread-A', 'runId': 'run-current'};
    const named = {'type': 'RUN_ERROR', ...input, 'message': 'Out of quota.'};
    const idless = {'type': 'RUN_ERROR', 'message': 'Unavailable'};
    final afterReplay = Stream<Map<String, Object?>>.fromIterable([
      {'type': 'RUN_STARTED', 'threadId': 'thread-A', 'runId': 'run-old'},
      {'type': 'RUN_FINISHED', 'threadId': 'thread-A', 'runId': 'run-old'},
      named,
    ]).transform(agUiRun(input));
    final first = Stream<Map<String, Object?>>.value(idless)
        .transform(agUiRun(input));

    await expectLater(afterReplay, emitsInOrder([named, emitsDone]));
    await expectLater(first, emitsInOrder([idless, emitsDone]));
  });

  test('a response that ends before the requested run started fails with an '
      'error that names the runs it started', () async {
    const start = {
      'type': 'RUN_STARTED',
      'threadId': 'thread-B',
      'runId': 'run-current',
    };
    final run = Stream<Map<String, Object?>>.fromIterable([
      start,
      {'type': 'TEXT_MESSAGE_CHUNK', 'messageId': 'm1', 'delta': 'Lost.'},
      {...start, 'type': 'RUN_FINISHED'},
    ]).transform(agUiRun({'threadId': 'thread-A', 'runId': 'run-current'}));

    await expectLater(
      run,
      emitsInOrder([
        emitsError(
          isFormatException.having(
            (error) => error.message,
            'message',
            contains('It started only run run-current of thread thread-B.'),
          ),
        ),
        emitsDone,
      ]),
    );
  });

  test('a source that fails before the requested run started gives only its '
      'own error', () async {
    final timeout = TimeoutException('No bytes for 60 s.');
    final run = Stream<Map<String, Object?>>.error(timeout)
        .transform(agUiRun({'threadId': 'thread-A', 'runId': 'run-current'}));

    await expectLater(run, emitsInOrder([emitsError(timeout), emitsDone]));
  });

  test('both listeners read only the requested run when one pauses', () async {
    final source = StreamController<Map<String, Object?>>.broadcast(sync: true);
    addTearDown(source.close);
    const start = {
      'type': 'RUN_STARTED',
      'threadId': 'thread-A',
      'runId': 'run-current',
    };
    const finish = {
      'type': 'RUN_FINISHED',
      'threadId': 'thread-A',
      'runId': 'run-current',
    };
    final run = source.stream.transform(
      agUiRun({'threadId': 'thread-A', 'runId': 'run-current'}),
    );
    final active = run.toList();
    final delayed = <Map<String, Object?>>[];
    final delayedDone = Completer<void>();
    final subscription = run.listen(delayed.add, onDone: delayedDone.complete);
    addTearDown(subscription.cancel);

    source.add({...start, 'runId': 'run-old'});
    subscription.pause();
    source
      ..add({
        'type': 'TOOL_CALL_CHUNK',
        'toolCallId': 'call-old',
        'toolCallName': 'place_order',
        'delta': '{}',
      })
      ..add({...finish, 'runId': 'run-old'})
      ..add(start);

    subscription.resume();
    await pumpEventQueue();
    source
      ..add({'type': 'TEXT_MESSAGE_CHUNK', 'messageId': 'm1', 'delta': 'New.'})
      ..add({
        'type': 'TOOL_CALL_CHUNK',
        'toolCallId': 'call-current',
        'toolCallName': 'set_quantity',
        'delta': '{}',
      })
      ..add(finish);

    final expected = [
      start,
      {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': 'New.'},
      {
        'type': 'TOOL_CALL_START',
        'toolCallId': 'call-current',
        'toolCallName': 'set_quantity',
      },
      {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'call-current', 'delta': '{}'},
      finish,
    ];
    expect(await active, expected);
    await delayedDone.future;
    expect(delayed, expected);
  });
}
