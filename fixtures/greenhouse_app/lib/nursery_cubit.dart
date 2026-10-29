import 'dart:async';

import 'package:greenhouse_app/contracts.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tandem/tandem.dart';

part 'nursery_cubit.g.dart';

/// A tray of seedlings, whose count the app changes in place.
class Tray({required var int seedlings});

/// A grower of the nursery, whom the backend names by a code.
final class const Grower(final String code);

final class const GrowerConverter() implements JsonConverter<Grower, String> {
  @override
  Grower fromJson(String json) => Grower(json);

  @override
  String toJson(Grower object) => object.code;
}

@TandemAgent(converters: [GrowerConverter()])
final class NurseryCubit(var List<PlantDTO> _plants, final List<Tray> _trays)
    with _$NurseryCubit {
  final _changes = StreamController<Object?>.broadcast();

  PlantDTO? opened;
  List<PlantDTO> compared = [];
  Tray? discarded;
  Grower? assigned;
  Grower? added;

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(plants),
    .sees(trays),
    .sees(growers),
    .calls(openPlant),
    .calls(comparePlants),
    .calls(reversePlants),
    .calls(keepFirst),
    .callsWithApproval(discardTray),
    .callsWithApproval(assignGrower),
    .calls(addGrower),
  ];

  @override
  Stream<Object?> get changes => _changes.stream;

  /// The plants of the nursery, by label.
  List<PlantDTO> get plants => _plants;

  /// The trays of seedlings on the benches.
  List<Tray> get trays => _trays;

  /// The growers of the nursery.
  List<Grower> get growers => const [Grower('ana'), Grower('ola')];

  /// Opens the page of [plant].
  void openPlant(PlantDTO plant) => opened = plant;

  /// Shows [plants] side by side.
  void comparePlants(List<PlantDTO> plants) => compared = plants;

  /// Lists the plants in reverse.
  void reversePlants() {
    _plants = [..._plants.reversed];
    _changes.add(null);
  }

  /// Keeps only the first plant.
  void keepFirst() {
    _plants = [..._plants.take(1)];
    _changes.add(null);
  }

  /// Throws [tray] away.
  void discardTray(Tray tray) => discarded = tray;

  /// Puts [grower] in charge of the greenhouse.
  void assignGrower(Grower grower) => assigned = grower;

  /// Adds [grower], whom the nursery does not list yet.
  void addGrower(@TandemInput() Grower grower) => added = grower;

  /// Thins the first tray to [seedlings], in place, as the app does.
  void thinFirstTray(int seedlings) {
    _trays.first.seedlings = seedlings;
    _changes.add(null);
  }
}
