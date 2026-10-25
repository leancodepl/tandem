import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/turn.dart';

import '../support/shop.dart';

void main() {
  late SeesSnapshot seen;

  setUp(() {
    final shop = Shop();
    addTearDown(shop.close);
    seen = .of(AgentListing.of(shop));
  });

  ToolCall call(String id) =>
      ToolCall(id, 'clear', 'Empties the list.', caller: .inAppAgent);

  test('one request shows at a time, in order', () {
    final turn = Turn([call('call-1'), call('call-2')])..ask(seen);

    final first = turn.next() ?? fail('Nothing shows.');
    expect(turn.next(), isNull);
    turn.approve(first);

    expect(turn.next()?.toolCallId, 'call-2');
  });

  test('the same decision twice does nothing, another throws', () {
    final turn = Turn([call('call-1')])..ask(seen);
    final pending = turn.next() ?? fail('Nothing shows.');
    final rejected = turn.reject(pending)?.request ?? fail('Not rejected.');

    expect(turn.reject(rejected), isNull);
    expect(() => turn.approve(rejected), throwsA(isA<ApprovalNotPending>()));
  });

  test('a rejection cancels the rest of the turn', () {
    final rest = call('call-2');
    final turn = Turn([call('call-1'), rest])..ask(seen);

    turn.reject(turn.next() ?? fail('Nothing shows.'));

    expect(rest.answer, ToolAnswer.cancelled);
    expect(turn.answered, isTrue);
  });

  test('invalidating what waits leaves answered and approved calls alone', () {
    final answered = call('call-1')..answer = .returned(null);
    final approved = call('call-2');
    final waiting = call('call-3');
    final turn = Turn([answered, approved, waiting])..ask(seen);
    turn.approve(turn.next() ?? fail('Nothing shows.'));

    expect(turn.invalidateWaiting(), [waiting]);
    expect(waiting.answer, ToolAnswer.invalidated);
    expect(
      [answered.answer?.status, approved.answer],
      [ToolStatus.returned, null],
    );
  });
}
