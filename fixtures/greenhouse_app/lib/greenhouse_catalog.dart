import 'package:greenhouse_app/plant_widgets.dart';
import 'package:kit_ds/kit_ds.dart';
import 'package:tandem/tandem.dart';

part 'greenhouse_catalog.g.dart';

/// Start with a KitStack. Show each plant of /plants as a PlantRow whose
/// onPick picks it, and the pots the user wants as a PotMeter below them.
///
/// ```json
/// [
///   {"id": "root", "component": "KitStack", "children": ["title", "rows", "pots"]},
///   {"id": "title", "component": "KitText", "style": "heading", "value": "Greenhouse"},
///   {"id": "rows", "component": "KitStack", "children": {"componentId": "row", "path": "/plants"}},
///   {"id": "row", "component": "PlantRow", "plant": {"path": ""},
///    "onPick": {"action": {"event": {"name": "pick", "context": {"plant": {"path": ""}}}}}},
///   {"id": "pots", "component": "PotMeter", "pots": {"path": "/wanted"}}
/// ]
/// ```
@TandemCatalog([
  ...Kit.components,
  PlantRow,
  PotMeter,
  UndoBar,
  PotsField,
  SideBySide,
  PageNumber,
])
final class const GreenhouseCatalog() with _$GreenhouseCatalog;
