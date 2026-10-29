import 'package:json_annotation/json_annotation.dart';

/// Marks a class for `tandem_generator`, which writes its `_$ClassName` mixin
/// from its `List<AgentCapability> get agentCapabilities`. A class without this
/// annotation gets no mixin, even with the getter.
final class const TandemAgent({
  /// The forms of types that Tandem cannot read from their declaration, such
  /// as `IconData`, for the values the agent sees and the arguments it
  /// sends. A converter for a type Tandem has one for, such as `Color`,
  /// replaces Tandem's. A design system exports its converters as a
  /// `static const` list, which the app spreads here.
  final List<JsonConverter<Object?, Object?>> converters = const [],
});

/// Marks a parameter of a listed method whose object the agent writes,
/// field by field or in its converter's form, such as a delivery that does
/// not exist yet. Without it, the agent points at an object it sees, with
/// `{"path": ...}`, so it cannot make one up. A converter does not change
/// that.
final class const TandemInput();
