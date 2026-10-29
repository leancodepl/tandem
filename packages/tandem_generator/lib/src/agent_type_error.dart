import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

final class AgentTypeError extends InvalidGenerationSource {
  new optionalList(Element element, {required String path})
    : super(
        '$path is a list, so the agent must send it: drop the ? and '
        'the default value.',
        element: element,
      );

  new unsupported(
    Element element, {
    required DartType type,
    required String path,
  }) : super(
         '$path: Tandem has no form for ${type.getDisplayString()}. It reads '
         'String, int, double, num, bool, DateTime, Uri, enums, classes whose '
         'values are their own static const members, extension types over '
         'these, lists and sets of them, and classes with a public '
         'constructor and a getter for each parameter.',
         element: element,
       );

  new missingConstructor(
    Element element, {
    required String className,
    required String path,
  }) : super(
         '$path: Tandem builds $className with its unnamed constructor, '
         'and it has no public one.',
         element: element,
       );

  new emptyConstructor(
    Element element, {
    required String className,
    required String path,
  }) : super(
         '$path: Tandem writes $className through its constructor parameters, '
         'and it has none.',
         element: element,
       );

  new positionalParameters(
    Element element, {
    required String className,
    required String path,
  }) : super(
         '$path: make the parameters of $className named, so that reordering '
         'them cannot swap values in code generated before.',
         element: element,
       );

  new missingGetter(
    Element element, {
    required String className,
    required String parameterName,
    required String path,
  }) : super(
         '$path: Tandem writes $className through the getters named like '
         'its constructor parameters, and it has no getter $parameterName.',
         element: element,
       );

  new getterType(
    Element element, {
    required String className,
    required String parameterName,
    required String path,
  }) : super(
         '$path: the getter $parameterName of $className must have the type '
         'of its constructor parameter, so that Tandem reads back what it '
         'writes.',
         element: element,
       );

  new recursiveClass(
    Element element, {
    required String className,
    required String path,
  }) : super('$path: $className contains itself.', element: element);

  new invalidValueConstructor(
    Element element, {
    required String className,
    required DartType valueType,
    required String path,
  }) : super(
         '$path: Tandem builds $className as $className(value), so its unnamed '
         'constructor must be public and take only the value: one positional, '
         'non-null ${valueType.getDisplayString()}.',
         element: element,
       );

  new unsupportedDefault(Element element, {required String parameterName})
    : super(
        'Tandem copies only literals, enum values, static const members and '
        'null as default values. Make $parameterName required or nullable '
        'instead.',
        element: element,
      );
}
