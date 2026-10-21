import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/protocol/apple_api.g.dart';
import 'package:tandem/tandem.dart';

import '../support/shop.dart';
import 'apple_api_test.g.dart';

Map<String, Object?> _input() => {
  'threadId': 'thread',
  'runId': 'run',
  'messages': <Object?>[],
  'tools': [
    {'name': 'add'},
    {'name': 'share'},
  ],
  'context': <Object?>[],
};

AppleCall _call(String id, String name, [String arguments = '{}']) =>
    AppleCall(id: id, name: name, arguments: arguments);

AppleReply _calls(List<AppleCall> calls) => AppleReply(calls: calls);

/// The Swift plugin, played by the test.
final class _Host({
  required final Future<AppleReply> Function(String requestId) reply,
  final Future<void> Function(String requestId)? onCancel,
}) implements TestAppleHostApi {
  final inputs = <Map<String, Object?>>[];
  final instructions = <String>[];
  final cancelled = <String>[];

  @override
  AppleAvailability availability() => .available;

  @override
  Future<AppleReply> run(
    String requestId,
    String inputJson,
    String instructions,
  ) {
    inputs.add(jsonDecode(inputJson) as Map<String, Object?>);
    this.instructions.add(instructions);
    return reply(requestId);
  }

  @override
  Future<void> cancel(String requestId) async {
    cancelled.add(requestId);
    await onCancel?.call(requestId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _Host install(_Host host) {
    TestAppleHostApi.setUp(host);
    addTearDown(() => TestAppleHostApi.setUp(null));
    return host;
  }

  test('the Apple factory returns the same connection', () {
    expect(OnDeviceAgent.apple(), same(OnDeviceAgent.apple()));
  });

  test('availability is unsupportedPlatform without the plugin', () async {
    expect(
      await OnDeviceAgent.apple().availability(),
      OnDeviceAvailability.unsupportedPlatform,
    );
  });

  testWidgets('a native batch runs in Tandem and its results go back', (
    tester,
  ) async {
    final shop = Shop();
    addTearDown(shop.close);
    late final _Host host;
    host = install(
      _Host(
        reply: (_) async => switch (host.inputs.length) {
          1 => _calls([
            _call('a', 'add', '{"item":"milk"}'),
            _call('b', 'add', '{"item":"bread"}'),
          ]),
          _ => AppleReply(text: 'Added.'),
        },
      ),
    );
    await tester.pumpWidget(
      TandemScope.connected(
        surface: (context) => shop,
        connection: OnDeviceAgent.apple(),
        approvals: const .fromState(),
        child: const SizedBox(),
      ),
    );
    final session = TandemSessionScope.of(tester.element(find.byType(SizedBox)))
      ..send('Add milk and bread.');
    await tester.pumpAndSettle();
    expect(shop.items, ['milk', 'bread']);
    expect(host.inputs, hasLength(2));
    final {'messages': messages as List<Object?>} = host.inputs.last;
    expect(
      messages.where((message) => message is Map && message['role'] == 'tool'),
      [
        allOf(containsPair('toolCallId', 'a'), containsPair('content', 'null')),
        allOf(containsPair('toolCallId', 'b'), containsPair('content', 'null')),
      ],
    );
    // Every run reads the screen as it is now.
    expect(host.instructions.last, contains(r'[\"milk\",\"bread\"]'));
    expect(session.items.whereType<AgentMessage>().single.text, 'Added.');
    expect(host.cancelled, isEmpty);
  });

  for (final invalid in [
    _call('b', 'removed'),
    _call('a', 'add'),
    _call('b', 'add', '[]'),
    _call('b', 'add', '{'),
  ]) {
    test(
      'an invalid sibling fails the entire native batch: ${invalid.encode()}',
      () async {
        install(
          _Host(reply: (_) async => _calls([_call('a', 'add'), invalid])),
        );
        final events = await OnDeviceAgent.apple().run(_input()).toList();
        expect(events.map((e) => e['type']), ['RUN_STARTED', 'RUN_ERROR']);
        expect(events.last['code'], OnDeviceErrorCode.invalidResponse);
      },
    );
  }

  test('native failures keep their code and emit no success', () async {
    install(
      _Host(
        reply: (_) async =>
            AppleReply(failure: .contextWindowExceeded, message: 'Too long.'),
      ),
    );
    final events = await OnDeviceAgent.apple().run(_input()).toList();
    expect(events.map((e) => e['type']), ['RUN_STARTED', 'RUN_ERROR']);
    expect(
      events.last,
      containsPair('code', OnDeviceErrorCode.contextWindowExceeded),
    );
  });

  test(
    'cancelling one of two runs waits for only its native cleanup',
    () async {
      final pending = <String, Completer<AppleReply>>{};
      final cleaned = Completer<void>();
      final host = install(
        _Host(
          reply: (id) => (pending[id] = Completer()).future,
          onCancel: (id) async {
            await cleaned.future;
            pending[id]?.complete(AppleReply(failure: .cancelled));
          },
        ),
      );
      final first = OnDeviceAgent.apple().run(_input()).listen((_) {});
      final secondEvents = OnDeviceAgent.apple().run(_input()).toList();
      await pumpEventQueue();
      expect(pending, hasLength(2));
      var cancelled = false;
      final cancel = first.cancel().then((_) => cancelled = true);
      await pumpEventQueue();
      expect(cancelled, isFalse);
      cleaned.complete();
      await cancel;
      expect(host.cancelled, [pending.keys.first]);
      pending[pending.keys.last]?.complete(
        AppleReply(text: 'Still running separately.'),
      );
      expect((await secondEvents).last['type'], 'RUN_FINISHED');
    },
  );
}
