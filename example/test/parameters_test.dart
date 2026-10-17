// Only Delivery: the generated code must build its Address without the name.
import 'dart:convert';

import 'package:example/delivery.dart' show Delivery;
import 'package:example/order.dart' show OrderLine;
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem_bloc/tandem_bloc.dart';
import 'package:tandem_bloc/testing.dart';

part 'parameters_test.g.dart';

enum Size() {
  s,
  m,
  l,
}

extension type const Sku(String value);

@TandemAgent()
class Shelf() with _$Shelf {
  final stocked = <String>[];

  @override
  List<AgentCapability> get agentCapabilities => [.calls(stock)];

  /// Puts [skus] on the shelf.
  void stock(
    List<Sku> skus,
    Size? size, {
    int count = 1,
    Size fit = .m,
    String? note = 'new',
  }) => stocked.add('$skus $size $count $fit $note');
}

@TandemAgent()
class Dispatch() with _$Dispatch {
  final booked = <String>[];

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(lastBooked),
    .calls(book),
  ];

  /// The delivery booked last, if any.
  Delivery? lastBooked;

  /// Books a courier for [lines] and returns the delivery as booked.
  Future<Delivery> book(List<OrderLine> lines, Delivery delivery) async {
    final what = [for (final line in lines) '${line.quantity} x ${line.sku}'];
    final Delivery(:address, :day, :slot) = delivery;
    final date = day.toIso8601String().substring(0, 10);
    booked.add('${what.join(', ')} to ${address.city} on $date, ${slot.name}');
    return lastBooked = delivery;
  }
}

const _delivery = {
  'address': {'street': 'Magazynowa 5', 'city': 'Poznań'},
  'day': '2026-10-23',
};

void main() {
  test('lists, enums, extension types, nullable and defaults', () async {
    final shelf = Shelf();
    final listing = AgentListing.of(shelf);

    expect(listing.tools.single['parameters'], {
      'type': 'object',
      'properties': {
        'skus': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'size': {
          'type': 'string',
          'enum': ['s', 'm', 'l'],
          'nullable': true,
        },
        'count': {'type': 'integer'},
        'fit': {
          'type': 'string',
          'enum': ['s', 'm', 'l'],
        },
        'note': {'type': 'string', 'nullable': true},
      },
      'required': ['skus'],
    });

    await listing.call('stock', {
      'skus': ['A', 'B'],
      'fit': 'l',
    });
    await listing.call('stock', {
      'skus': ['C'],
      'note': null,
    });
    expect(shelf.stocked, [
      '[A, B] null 1 Size.l new',
      '[C] null 1 Size.m null',
    ]);

    await expectLater(
      listing.call('stock', {
        'skus': ['A'],
        'count': null,
      }),
      throwsA(
        isA<ToolCallRefused>().having(
          (error) => error.message,
          'message',
          'count: expected int, got null',
        ),
      ),
    );

    await expectLater(
      listing.call('stock', {'skus': null}),
      throwsA(
        isA<ToolCallRefused>().having(
          (error) => error.message,
          'message',
          'skus: expected a list, got null',
        ),
      ),
    );

    await expectLater(
      listing.call('stock', {
        'skus': ['A'],
        'size': 'xl',
      }),
      throwsA(
        isA<ToolCallRefused>().having(
          (error) => error.message,
          'message',
          'size: expected one of s, m, l, got "xl"',
        ),
      ),
    );
  });

  test(
    'plain classes: the schema comes from constructors and doc comments',
    () {
      expect(AgentListing.of(Dispatch()).tools.single['parameters'], {
        'type': 'object',
        'properties': {
          'lines': {
            'type': 'array',
            'items': {
              'type': 'object',
              'description':
                  'One product of an order and how many pieces of it.',
              'properties': {
                'sku': {
                  'type': 'string',
                  'description': "The product's code in the catalog.",
                },
                'quantity': {
                  'type': 'integer',
                  'description': 'How many pieces.',
                },
              },
              'required': ['sku', 'quantity'],
            },
          },
          'delivery': {
            'type': 'object',
            'description': 'Where and when an order goes.',
            'properties': {
              'address': {
                'type': 'object',
                'description': 'Where the courier brings the order.',
                'properties': {
                  'street': {'type': 'string'},
                  'city': {'type': 'string'},
                },
                'required': ['street', 'city'],
              },
              'day': {
                'type': 'string',
                'format': 'date-time',
                'description': 'The day the order arrives.',
              },
              'slot': {
                'type': 'string',
                'enum': ['morning', 'afternoon'],
              },
              'note': {
                'type': 'string',
                'nullable': true,
                'description': 'Anything the courier should know.',
              },
            },
            'required': ['address', 'day'],
          },
        },
        'required': ['lines', 'delivery'],
      });
    },
  );

  test(
    'the JSON becomes objects through their constructors, and back',
    () async {
      final dispatch = Dispatch();
      expect(AgentListing.of(dispatch).context.single['value'], 'null');

      final result = await AgentListing.of(dispatch).call('book', {
        'lines': [
          {'sku': 'VM-27Q', 'quantity': 15.0},
          {'sku': 'VC-HDMI-2M', 'quantity': 40},
        ],
        'delivery': _delivery,
      });

      expect(dispatch.booked, [
        '15 x VM-27Q, 40 x VC-HDMI-2M to Poznań on 2026-10-23, morning',
      ]);
      expect(result, {
        'address': {'street': 'Magazynowa 5', 'city': 'Poznań'},
        'day': '2026-10-23T00:00:00.000',
        'slot': 'morning',
        'note': null,
      });
      expect(
        AgentListing.of(dispatch).context.single['value'],
        jsonEncode(result),
      );
    },
  );

  test('a wrong value deep inside names its path; nothing runs', () async {
    final dispatch = Dispatch();
    final listing = AgentListing.of(dispatch);
    Matcher message(String text) => throwsA(
      isA<ToolCallRefused>().having((error) => error.message, 'message', text),
    );

    await expectLater(
      listing.call('book', {
        'lines': [
          {'sku': 'VM-27Q', 'quantity': 15},
          {'sku': 'VC-HDMI-2M', 'quantity': 'forty'},
        ],
        'delivery': _delivery,
      }),
      message('lines[1].quantity: expected int, got "forty"'),
    );
    await expectLater(
      listing.call('book', {
        'lines': <Object?>[],
        'delivery': {
          'address': {'street': 'Magazynowa 5'},
          'day': '2026-10-23',
        },
      }),
      message('delivery.address.city: missing, expected String'),
    );
    await expectLater(
      listing.call('book', {
        'lines': <Object?>[],
        'delivery': {..._delivery, 'notes': 'Leave at the back door'},
      }),
      message(
        'delivery.notes: unknown, expected one of address, day, slot, note',
      ),
    );
    await expectLater(
      listing.call('book', {
        'lines': [
          {'sku': 'VM-27Q', 'quantity': 1e30},
        ],
        'delivery': _delivery,
      }),
      message('lines[0].quantity: expected int, got 1e+30'),
    );
    for (final day in [
      '2026-02-30',
      '2026-10-23T10:20:99',
      '2026-10-23T102099',
      '2026-10-23T10:20+02:60',
      '2026-10-23T10:20+0299',
      '2026-10-23T10:20+24:00',
      '2026-10-23T10:20-2400',
      '2026-10-23T10:20+24',
    ]) {
      await expectLater(
        listing.call('book', {
          'lines': <Object?>[],
          'delivery': {..._delivery, 'day': day},
        }),
        message('delivery.day: expected an ISO 8601 date, got "$day"'),
      );
    }
    expect(dispatch.booked, isEmpty);
  });

  test('a date keeps its time zone and fraction of a second', () {
    for (final day in [
      '2026-10-23T10:20:59.5+02:00',
      '2026-10-23 08:20:59,500Z',
    ]) {
      expect(
        ToolArgs({'day': day}).read<DateTime>('day'),
        DateTime.utc(2026, 10, 23, 8, 20, 59, 500),
      );
    }
  });

  test('a zone offset reads from -23:59 to +23:59 in every form', () {
    final instants = {
      '2026-10-23T10:20+23:59': DateTime.utc(2026, 10, 22, 10, 21),
      '2026-10-23T10:20-2359': DateTime.utc(2026, 10, 24, 10, 19),
      '2026-10-23T10:20+00': DateTime.utc(2026, 10, 23, 10, 20),
      '2026-10-23T10:20-02': DateTime.utc(2026, 10, 23, 12, 20),
    };
    for (final MapEntry(key: day, value: instant) in instants.entries) {
      expect(ToolArgs({'day': day}).read<DateTime>('day'), instant);
    }
  });

  test('an int refuses a whole double past 2^53 - 1, not an exact int', () {
    T read<T>(String json) => ToolArgs({'n': jsonDecode(json)}).read<T>('n');

    expect(read<int>('9007199254740991.0'), 9007199254740991);
    expect('${read<int>('9007199254740993')}', '9007199254740993');
    expect(read<double>('1e30'), 1e30);
    expect(read<num?>('1e30'), 1e30);
    for (final readInt in [read<int>, read<int?>]) {
      expect(
        () => readInt('9007199254740993.0'),
        throwsA(
          isA<ToolCallRefused>().having(
            (error) => error.message,
            'message',
            'n: expected int, got 9007199254740992.0',
          ),
        ),
      );
    }
  });
}
