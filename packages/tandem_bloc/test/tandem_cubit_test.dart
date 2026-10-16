import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

import 'support.dart';

void main() {
  group('TandemCubit', () {
    late OrderCubit host;

    setUp(() => host = OrderCubit());
    tearDown(() => host.close());

    TandemSession<OrderState> sessionWith(AgentConnection connection) =>
        TandemSession(connection: connection, host: host, codec: orderCodec);

    test('starts with the view of the session and mirrors every new '
        'one', () async {
      final session = sessionWith(
        ScriptedAgent([
          (request) => const [AgentStep.say('Hello there.')],
        ]),
      );
      final cubit = TandemCubit(session);
      addTearDown(cubit.close);
      final views = <TandemView>[];
      cubit.stream.listen(views.add);

      expect(cubit.state, same(session.view));

      await cubit.send('Hi');
      await pumpEventQueue();

      expect(cubit.state, same(session.view));
      expect(cubit.state.isRunning, isFalse);
      expect(cubit.state.timeline, [
        isA<UserMessage>().having((message) => message.text, 'text', 'Hi'),
        isA<AgentMessage>()
            .having((message) => message.text, 'text', 'Hello there.')
            .having((message) => message.isStreaming, 'isStreaming', false),
      ]);
      expect(views.first.isRunning, isTrue);
      expect(
        views.any(
          (view) => view.timeline.any(
            (item) => item is AgentMessage && item.isStreaming,
          ),
        ),
        isTrue,
        reason: 'the streamed text arrives view by view',
      );
    });

    test('stop cancels the run of the session', () async {
      final never = Completer<void>();
      final session = sessionWith(
        ScriptedAgent([
          (request) => [
            const AgentStep.say('Looking.'),
            AgentStep.waitFor(never.future),
          ],
        ]),
      );
      final cubit = TandemCubit(session);
      addTearDown(cubit.close);

      final sent = cubit.send('Hi');
      await pumpEventQueue();

      expect(cubit.state.isRunning, isTrue);

      await cubit.stop();
      await sent;
      await pumpEventQueue();

      expect(cubit.state.isRunning, isFalse);
      expect(cubit.state.error, isNull);
    });

    test('close stops mirroring the session at once', () async {
      final cubit = TandemCubit(sessionWith(LiveConnection()));
      final sent = cubit.send('Hi');
      await pumpEventQueue();
      final views = <TandemView>[];
      cubit.stream.listen(views.add);

      await cubit.close();
      await sent;

      expect(views, isEmpty, reason: 'the stopped run is not shown');
    });

    test('close disposes the session', () async {
      final session = sessionWith(ScriptedAgent(const []));
      final cubit = TandemCubit(session);

      await cubit.close();

      expect(cubit.isClosed, isTrue);
      expect(() => session.send('Hi'), throwsStateError);
    });

    test('close stops the session writing into the host before anything '
        'else', () async {
      final connection = LiveConnection();
      final cubit = TandemCubit(sessionWith(connection));

      unawaited(cubit.send('40 for Acme'));
      connection.send(draftDelta(const OrderDraft(customer: 'Acme')));

      expect(host.state.draft, const OrderDraft(customer: 'Acme'));

      // What the BlocProviders do when the screen closes: the scope's
      // provider closes the TandemCubit, then the provider above closes the
      // host, and neither waits. An agent event may arrive right after.
      final closing = [cubit.close(), host.close()];
      connection.send(
        draftDelta(const OrderDraft(customer: 'Acme', quantity: 40)),
      );
      await Future.wait(closing);

      expect(connection.isListening, isFalse);
      expect(host.state.draft, const OrderDraft(customer: 'Acme'));
    });
  });
}
