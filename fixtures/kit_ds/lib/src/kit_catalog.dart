import 'package:kit_ds/src/kit.dart';
import 'package:kit_ds/src/kit_widgets.dart';
import 'package:tandem/tandem.dart';

part 'kit_catalog.g.dart';

/// Draw a stack of a heading, a chip that says what is in stock, and a button
/// for the action the user asked for.
///
/// ```json
/// [
///   {"id": "root", "component": "KitStack", "children": ["title", "stock"]},
///   {"id": "title", "component": "KitText", "style": "heading", "value": "Greenhouse"},
///   {"id": "stock", "component": "KitChip", "fill": "#2E7D32", "text": "In stock"}
/// ]
/// ```
@TandemCatalog([...Kit.components])
final class const KitCatalog() with _$KitCatalog;
