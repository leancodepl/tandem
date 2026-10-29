import 'dart:async';

import 'package:greenhouse_app/contracts.dart' show Page, PlantDTO, Sku;
import 'package:kit_ds/kit_ds.dart';
import 'package:tandem/tandem.dart';

part 'stock_cubit.g.dart';

@TandemAgent()
final class StockCubit(final List<PlantDTO> _plants) with _$StockCubit {
  final _changes = StreamController<Object?>.broadcast();

  final restocked = <Sku, int>{};
  final groups = <String>{};
  List<int?> benches = [];

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(plants),
    .sees(page),
    .sees(titleStyle),
    .calls(restock),
    .calls(group),
  ];

  @override
  Stream<Object?> get changes => _changes.stream;

  /// The plants in stock, by label.
  List<PlantDTO> get plants => _plants;

  /// The first page of the stock.
  Page<PlantDTO> get page => .new(items: _plants, number: 1);

  /// The style of the screen's title.
  KitStyle get titleStyle => .heading;

  /// Orders [count] more pots of [sku] from the grower.
  void restock(Sku sku, int count) => restocked[sku] = count;

  /// Files the stock under [names] and sets it out on [benches], null for the
  /// floor.
  void group(Set<String> names, List<int?> benches) {
    groups.addAll(names);
    this.benches = benches;
  }
}
