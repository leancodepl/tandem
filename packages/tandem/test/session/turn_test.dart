import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/chat/chat_item.dart';
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

  ToolCall call(String id) => ToolCall(id, 'clear', 'Empties the list.');

  test('only a pending request can be decided', () {
    final clear = call('call-1');
    final turn = Turn([clear]);
    final [request] = turn.ask(seen);

    expect(turn.reject(request), same(clear));
    expect(turn.approve(request), isNull);
    expect(clear.request?.status, ApprovalStatus.rejected);
    expect(clear.answer, ToolAnswer.rejected);
  });

  test('invalidating what waits leaves answered and approved calls alone', () {
    final answered = call('call-1')..answer = .returned(null);
    final approved = call('call-2');
    final waiting = call('call-3');
    final turn = Turn([answered, approved, waiting]);
    final [first, _] = turn.ask(seen);
    turn.approve(first);

    expect(turn.invalidateWaiting(), [waiting]);
    expect(waiting.request?.status, ApprovalStatus.invalidated);
    expect([answered.answer, approved.answer], ['null', null]);
  });
}
