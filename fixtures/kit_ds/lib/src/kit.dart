import 'package:json_annotation/json_annotation.dart';
import 'package:kit_ds/src/kit_ink.dart';
import 'package:kit_ds/src/kit_widgets.dart';

/// What the kit gives an app's Tandem catalog and agents.
abstract final class Kit() {
  static const components = [KitText, KitNote, KitStack, KitButton, KitChip];

  static const converters = <JsonConverter<Object?, Object?>>[InkConverter()];
}
