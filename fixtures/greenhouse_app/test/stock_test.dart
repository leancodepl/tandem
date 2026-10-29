import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/contracts.dart';
import 'package:greenhouse_app/stock_cubit.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

void main() {
  test('a contract DTO reads by its constructor, not its toJson', () {
    final listing = AgentListing.of(StockCubit([_plant]));

    expect(listing.seen['plants'], [_plantJson]);
  });

  test('a token, a generic class and an extension type keep their names', () {
    final cubit = StockCubit([_plant]);
    final listing = AgentListing.of(cubit);
    final types = {
      for (final view in cubit.agentSchema.sees) view.name: view.type.id,
    };

    expect(listing.seen['page'], {
      'items': [_plantJson],
      'number': 1,
    });
    expect(listing.seen['title_style'], 'heading');
    expect(
      types['page'],
      'package:greenhouse_app/contracts.dart#Page'
      '<package:greenhouse_app/contracts.dart#PlantDTO>',
    );
    expect(types['title_style'], 'package:kit_ds/src/kit_style.dart#KitStyle');
  });

  test(
    'an int takes 4.0 and refuses 1.9; a set and null items come through',
    () async {
      final cubit = StockCubit([_plant]);
      final listing = AgentListing.of(cubit);

      await expectLater(
        listing.call('restock', {'sku': 'p1', 'count': 1.9}),
        throwsA(
          isA<ToolCallRefused>().having(
            (error) => error.message,
            'message',
            'count: expected int, got 1.9',
          ),
        ),
      );
      await listing.call('restock', {'sku': 'p1', 'count': 4.0});
      await listing.call('group', {
        'names': ['indoor', 'indoor', 'shade'],
        'benches': [3, null],
      });

      expect(cubit.restocked, {const Sku('p1'): 4});
      expect(cubit.groups, {'indoor', 'shade'});
      expect(cubit.benches, [3, null]);
    },
  );
}

const _plantJson = {
  'sku': 'p1',
  'label': 'Maidenhair fern',
  'light': 'partShade',
  'sizes': [
    {'diameterCm': 12, 'liters': 0.75, 'glazed': true},
  ],
  'pottedOn': '2026-03-14T00:00:00.000Z',
  'careSheet': 'https://care.example.com/p1.pdf',
};

final _plant = PlantDTO(
  sku: 'p1',
  label: 'Maidenhair fern',
  light: .partShade,
  sizes: [.new(diameterCm: 12, liters: 0.75, glazed: true)],
  pottedOn: .utc(2026, 3, 14),
  careSheet: .parse('https://care.example.com/p1.pdf'),
);
