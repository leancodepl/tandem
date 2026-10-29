import 'package:json_annotation/json_annotation.dart';
import 'package:kit_ds/src/kit_ink.dart';

/// What the kit gives an app's Tandem catalog and agents.
abstract final class Kit() {
  static const converters = <JsonConverter<Object?, Object?>>[InkConverter()];
}
