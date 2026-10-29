import 'dart:async';

import 'package:greenhouse_app/contracts.dart';
import 'package:tandem/tandem.dart';

part 'browse_cubit.g.dart';

/// A shelf of a shop, with the names of its items.
class const Shelf({
  required final String name,
  required final List<String> items,
});

/// A file the user attaches to the note.
class const Attachment({
  required final String path,
  required final String title,
});

/// The screen the view tests draw on.
@TandemAgent()
final class BrowseCubit(
  var List<PlantDTO> _plants, {
  var List<Shelf> _shelves = const [],
  var Shelf? _featured,
}) with _$BrowseCubit {
  final _changes = StreamController<Object?>.broadcast();

  bool canPick = true;
  bool canPutBack = true;
  bool showsNote = true;
  PlantDTO? picked;
  final putBack = <String>[];
  int pots = 2;
  final composted = <String>[];
  final notes = <String?>[];
  final kept = <String>[];
  final attached = <String>[];
  final compared = <List<List<PlantDTO>>>[];

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(plants),
    .sees(shelves),
    .sees(featured),
    .sees(pairs),
    .sees(wanted),
    .sees(labels),
    if (showsNote) .sees(note),
    if (canPick) .calls(pick),
    if (canPutBack) .calls(putBackPlant),
    .calls(setPots),
    .calls(setNote),
    .calls(keepNote),
    .calls(attach),
    .calls(compare),
    .callsWithApproval(compost),
  ];

  @override
  Stream<Object?> get changes => _changes.stream;

  /// The plants of the greenhouse, by label.
  List<PlantDTO> get plants => _plants;

  /// The shelves of the shop.
  List<Shelf> get shelves => _shelves;

  /// The shelf the shop puts first, null without one.
  Shelf? get featured => _featured;

  /// The plants two by two, for the user to compare.
  List<List<PlantDTO>> get pairs => [
    for (var i = 0; i + 1 < _plants.length; i += 2)
      [_plants[i], _plants[i + 1]],
  ];

  /// How many pots the user wants.
  int get wanted => pots;

  /// The labels of the plants, on one page.
  Page<String> get labels =>
      .new(items: [for (final plant in _plants) plant.label], number: 1);

  /// The user's note on the plants, null without one.
  String? get note => notes.lastOrNull;

  /// Picks [plant].
  void pick(PlantDTO plant) => picked = plant;

  /// Puts [plant] back on its bench.
  void putBackPlant(PlantDTO plant) => putBack.add(plant.sku);

  /// Sets how many pots the user wants.
  void setPots(int pots) {
    this.pots = pots;
    changed();
  }

  /// Sets the note, or clears it with null.
  void setNote(String? note) => notes.add(note);

  /// Keeps [note].
  void keepNote(String note) => kept.add(note);

  /// Attaches [file] to the note.
  void attach(@TandemInput() Attachment file) => attached.add(file.path);

  /// Compares the plants of each pair of [pairs].
  void compare(List<List<PlantDTO>> pairs) => compared.add(pairs);

  /// Composts [plant], which cannot be undone.
  void compost(PlantDTO plant) => composted.add(plant.sku);

  void setPlants(List<PlantDTO> plants) {
    _plants = plants;
    changed();
  }

  void setShelves(List<Shelf> shelves) {
    _shelves = shelves;
    changed();
  }

  void setFeatured(Shelf? shelf) {
    _featured = shelf;
    changed();
  }

  void changed() => _changes.add(null);
}
