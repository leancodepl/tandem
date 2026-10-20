import 'package:analyzer/dart/element/element.dart';
import 'package:tandem_generator/src/tokens.dart';

/// The doc comment without the slashes. Field getters use the field's comment.
String? documentationOf(Element? element) {
  final comment = switch (element) {
    GetterElement(isOriginVariable: true, :final variable) =>
      variable.documentationComment,
    _ => element?.documentationComment,
  };
  final prefix = RegExp(r'^\s*/// ?');

  return comment
      ?.split(Tokens.newLine)
      .map((line) => line.replaceFirst(prefix, ''))
      .join(Tokens.newLine)
      .trim();
}
