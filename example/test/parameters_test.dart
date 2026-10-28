import 'dart:async';
import 'dart:convert';

import 'package:example/order.dart' show OrderLine;
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

// Only Delivery: the generated code must build its Address without the name.
import 'delivery.dart' show Delivery;

part 'parameters_test.g.dart';

enum Size() {
  s,
  m,
  l,
}

enum StockStatus(final String name) {
  ready('Ready to stock'),
  sent('Already sent'),
}

class const EnumSample({
  required final Size size,
  required final StockStatus status,
  required final StockStatus? optionalStatus,
  required final List<StockStatus> statuses,
});

@TandemAgent()
class EnumShelf() with _$EnumShelf {
  @override
  List<AgentCapability> get agentCapabilities => [.sees(sample), .calls(echo)];

  @override
  Stream<Object?> get changes => const Stream.empty();

  /// The shelf's current and previous statuses.
  EnumSample sample = const .new(
    size: .m,
    status: .ready,
    optionalStatus: .sent,
    statuses: [.ready, .sent],
  );

  /// Stores and returns [sample].
  EnumSample echo(EnumSample sample) => this.sample = sample;
}

extension type const Sku(String value);

@TandemAgent()
class Shelf() with _$Shelf {
  final stocked = <String>[];

  @override
  List<AgentCapability> get agentCapabilities => [.calls(stock)];

  @override
  Stream<Object?> get changes => const Stream.empty();

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
    .calls(setDelivery),
    .calls(findDelivery),
    .calls(deliveryDay),
  ];

  @override
  Stream<Object?> get changes => const Stream.empty();

  /// The delivery booked last, if any.
  Delivery? lastBooked;

  /// Replaces or clears the delivery.
  void setDelivery(Delivery? delivery) => lastBooked = delivery;

  /// Finds the last booked delivery, if any.
  Future<Delivery>? findDelivery() {
    final delivery = lastBooked;

    if (delivery == null) return null;

    return Future.value(delivery);
  }

  /// The day of the last booked delivery, if any.
  FutureOr<DateTime>? deliveryDay() => lastBooked?.day;

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
  'day': '2026-10-23T00:00:00Z',
};

void main() {
  test(
    'enum constant names survive views, results and argument round trips',
    () async {
      final shelf = EnumShelf();
      final listing = AgentListing.of(shelf);

      for (final optional in ['sent', null]) {
        final expected = {
          'size': 'm',
          'status': 'ready',
          'optionalStatus': optional,
          'statuses': ['ready', 'sent'],
        };
        final result = await listing.call('echo', {'sample': expected});
        expect(result, expected);

        final visible = switch (AgentListing.of(shelf)
            .context
            .single['value']) {
          final String value => jsonDecode(value),
          _ => fail('The view did not contain JSON.'),
        };
        expect(visible, expected);
        expect(await listing.call('echo', {'sample': visible}), expected);
        expect(await listing.call('echo', {'sample': result}), expected);
      }
    },
  );

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
          'anyOf': [
            {
              'type': 'string',
              'enum': ['s', 'm', 'l'],
            },
            {'type': 'null'},
          ],
        },
        'count': {'type': 'integer'},
        'fit': {
          'type': 'string',
          'enum': ['s', 'm', 'l'],
        },
        'note': {
          'anyOf': [
            {'type': 'string'},
            {'type': 'null'},
          ],
        },
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
      expect(AgentListing.of(Dispatch()).tools.first['parameters'], {
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
                'anyOf': [
                  {'type': 'string'},
                  {'type': 'null'},
                ],
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
        'day': '2026-10-23T00:00:00.000Z',
        'slot': 'morning',
        'note': null,
      });
      expect(
        AgentListing.of(dispatch).context.single['value'],
        jsonEncode(result),
      );
    },
  );

  test('nullable futures return null or the encoded result', () async {
    final listing = AgentListing.of(Dispatch());

    expect(await listing.call('find_delivery', {}), isNull);
    expect(await listing.call('delivery_day', {}), isNull);

    await listing.call('set_delivery', {'delivery': _delivery});

    expect(await listing.call('find_delivery', {}), {
      'address': {'street': 'Magazynowa 5', 'city': 'Poznań'},
      'day': '2026-10-23T00:00:00.000Z',
      'slot': 'morning',
      'note': null,
    });
    expect(await listing.call('delivery_day', {}), '2026-10-23T00:00:00.000Z');
  });

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
    await expectLater(
      listing.call('book', {
        'lines': <Object?>[],
        'delivery': {..._delivery, 'day': '23 Oct 2026'},
      }),
      message('delivery.day: expected an ISO 8601 date, got "23 Oct 2026"'),
    );
    expect(dispatch.booked, isEmpty);
  });

  test('nullable objects reject unknown fields before the method runs', () async {
    final dispatch = Dispatch();
    final listing = AgentListing.of(dispatch);

    await expectLater(
      listing.call('set_delivery', {
        'delivery': {
          ..._delivery,
          'address': {
            'street': 'Magazynowa 5',
            'city': 'Poznań',
            'street_typo': 'Unknown',
          },
        },
      }),
      throwsA(
        isA<ToolCallRefused>().having(
          (error) => error.message,
          'message',
          'delivery.address.street_typo: unknown, expected one of street, city',
        ),
      ),
    );
    expect(dispatch.lastBooked, isNull);

    await listing.call('set_delivery', {'delivery': _delivery});
    expect(dispatch.lastBooked?.address.city, 'Poznań');
    await listing.call('set_delivery', {'delivery': null});
    expect(dispatch.lastBooked, isNull);
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
