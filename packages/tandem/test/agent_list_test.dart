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
}

final class _Gauge(final double ratio) implements AgentSurface {
  @override
  List<AgentCapability> get agentCapabilities => [.sees(ratio)];

  @override
  Stream<Object?> get changes => const Stream.empty();

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [AgentView.of(() => ratio).as('ratio', 'How full it is.', .number)],
    calls: const [],
  );
}

final class _Pot(final String name);

final class _Studio() implements AgentSurface {
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
          name: 'paint',
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
