import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/tandem.dart';

void main() {
  test("a parameter's doc comment goes before its type's description", () {
    final properties = switch (AgentListing.of(_Studio()).tools.single) {
      {'parameters': {'properties': final Map<String, Object?> properties}} =>
        properties,
      _ => const <String, Object?>{},
    };

    expect(properties['tint'], {
      'type': 'string',
      'description': startsWith('The tint. A color as #RRGGBB'),
    });
    expect(
      properties['pot'],
      containsPair(
        'description',
        startsWith('The pot to paint. A path to a Pot'),
      ),
    );
  });

  test('a .sees that cannot be written as JSON names its getter', () {
    expect(
      () => AgentListing.of(_Gauge(double.nan)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          startsWith('The agent list cannot write the .sees ratio: '),
        ),
      ),
    );
  });

  test('a .sees of another type than the generated code asks for a build', () {
    expect(
      () => AgentListing.of(_Gauge(0.5, listed: 'ten')),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'The agent list sees a String as ratio, the generated code a '
              'double. Run build_runner again.',
        ),
      ),
    );
  });

  test('a .sees from outside agentCapabilities is refused', () {
    expect(
      () => AgentListing.of(_Split()),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          startsWith('A .sees comes from outside agentCapabilities'),
        ),
      ),
    );
  });

  test('a method whose tool starts with tandem_ is refused', () {
    expect(
      () => AgentListing.of(_Studio(method: 'tandem_show_view')),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          startsWith('The agent list calls tandem_show_view'),
        ),
      ),
    );
  });

  test('the arguments a call reports cannot be changed', () async {
    final (:arguments, result: _) = await AgentListing.of(_Studio()).run(
      'paint',
      const WrittenArguments({
        'pot': {'path': '/pots/0'},
        'tint': '#ff0000',
      }),
      approved: false,
    );
    final pot = switch (arguments['pot']) {
      final Map<String, Object?> pot => pot,
      _ => <String, Object?>{},
    };

    expect(pot, {'name': 'fern'});
    expect(() => arguments['tint'] = '#000000', throwsUnsupportedError);
    expect(() => pot['name'] = 'redacted', throwsUnsupportedError);
  });
}

/// Lists its `.sees` in a getter that `agentCapabilities` spreads, which the
/// generated copy keeps as it is.
final class _Split() implements AgentSurface {
  final ratio = 0.5;

  List<AgentCapability> get _gauges => [.sees(ratio)];

  @override
  List<AgentCapability> get agentCapabilities => [..._gauges];

  @override
  Stream<Object?> get changes => const Stream.empty();

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [AgentView.of(() => ratio).as('ratio', 'How full it is.', .number)],
    calls: const [],
    capabilities: () => [..._gauges],
  );
}

final class _Gauge(final double ratio, {final Object? listed})
    implements AgentSurface {
  @override
  List<AgentCapability> get agentCapabilities => [.sees(listed ?? ratio)];

  @override
  Stream<Object?> get changes => const Stream.empty();

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [AgentView.of(() => ratio).as('ratio', 'How full it is.', .number)],
    calls: const [],
  );
}

final class _Pot(final String name);

final class _Studio({final String method = 'paint'}) implements AgentSurface {
  final pots = [_Pot('fern')];

  void paint(_Pot pot, Color tint) {}

  @override
  List<AgentCapability> get agentCapabilities => [.sees(pots), .calls(paint)];

  @override
  Stream<Object?> get changes => const Stream.empty();

  @override
  AgentSchema get agentSchema {
    final AgentType<_Pot> pot = .object(
      id: 'test#Pot',
      fields: (field) => [field('name', (pot) => pot.name).as(.string)],
      build: (values) => _Pot(values('name')),
    );
    return AgentSchema(
      sees: [AgentView.of(() => pots).as('pots', 'The pots.', .list(pot))],
      calls: [
        AgentTool(
          paint,
          name: method,
          description: 'Paints [pot] in [tint].',
          parameters: [
            AgentParameter('pot', pot, description: 'The pot to paint.'),
            const AgentParameter('tint', .color, description: 'The tint.'),
          ],
          invoke: (args) {
            paint(args.read('pot'), args.read('tint'));
            return null;
          },
        ),
      ],
    );
  }
}
