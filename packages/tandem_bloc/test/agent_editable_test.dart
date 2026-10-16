import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

import 'support.dart';

void main() {
  group('AgentEditable', () {
    test('emits what the agent writes like any other state', () async {
      final cubit = OrderCubit();
      addTearDown(cubit.close);
      final states = <OrderState>[];
      cubit.stream.listen(states.add);

      const written = OrderState(draft: OrderDraft(customer: 'Acme'));
      cubit.writeFromAgent(written);

      expect(cubit.state, written);
      await pumpEventQueue();
      expect(states, [written]);
    });

    test('makes a Cubit the state host of a session', () async {
      final cubit = OrderCubit(const OrderState(isExpanded: true));
      final agent = ScriptedAgent([
        (request) {
          expect(request.state, {
            'order': {'customer': '', 'quantity': 0},
          });
          return const [
            AgentStep.patchState([
              {
                'op': 'replace',
                'path': '/order',
                'value': {'customer': 'Acme', 'quantity': 40},
              },
            ]),
            AgentStep.say('Filled in.'),
          ];
        },
        (request) {
          // The cubit's echo of the agent's write is not a user edit; the
          // user's change of the quantity is.
          expect(request.reportedUserEdits, ['/order/quantity']);
          expect(request.state, {
            'order': {'customer': 'Acme', 'quantity': 15},
          });
          return const [AgentStep.say('Fifteen it is.')];
        },
      ]);
      final session = TandemSession<OrderState>(
        connection: agent,
        host: cubit,
        codec: orderCodec,
      );
      addTearDown(() async {
        await session.dispose();
        await cubit.close();
      });

      await session.send('40 for Acme');
      await pumpEventQueue();

      expect(
        cubit.state,
        const OrderState(
          draft: OrderDraft(customer: 'Acme', quantity: 40),
          // The lens keeps what the agent does not see.
          isExpanded: true,
        ),
      );
      expect(session.view.marks.paths, {'customer', 'quantity'});

      cubit.setQuantity(15);
      await pumpEventQueue();

      expect(session.view.marks.paths, {'customer'});

      await session.send('Make it 15');

      expect(agent.isExhausted, isTrue);
      expect(session.view.error, isNull);
    });

    test('on a Bloc, emits what the agent writes without an event', () async {
      final bloc = NotesBloc();
      addTearDown(bloc.close);

      bloc.add(const NotesEvent('By hand'));
      await pumpEventQueue();
      bloc.writeFromAgent(const NotesState('From the agent'));
      await pumpEventQueue();

      expect(bloc.state, const NotesState('From the agent'));
      expect(bloc.handled, [const NotesEvent('By hand')]);
    });
  });
}

final class NotesState {
  const NotesState(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is NotesState && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

final class NotesEvent {
  const NotesEvent(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is NotesEvent && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// A Bloc that records the events it handled.
class NotesBloc extends Bloc<NotesEvent, NotesState>
    with AgentEditable<NotesState> {
  NotesBloc() : super(const NotesState('')) {
    on<NotesEvent>((event, emit) {
      handled.add(event);
      emit(NotesState(event.text));
    });
  }

  final handled = <NotesEvent>[];
}
