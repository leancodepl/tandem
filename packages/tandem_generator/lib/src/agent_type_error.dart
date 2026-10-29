import 'package:analyzer/dart/constant/value.dart';
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
         'constructor and a getter for each parameter. A '
         'JsonConverter<${type.getDisplayString()}, S> in converters: gives '
         'it a form.',
         element: element,
       );

  new twoConverters(
    Element element, {
    required DartType converted,
    required String first,
    required String second,
  }) : super(
         'converters: has two for ${converted.getDisplayString()}, $first and '
         '$second. Keep one.',
         element: element,
       );

  new nullableConverter(
    Element element, {
    required String className,
    required DartType converted,
    required DartType nonNull,
    required DartType json,
  }) : super(
         'converters: $className converts ${converted.getDisplayString()}, '
         'and a converter matches the type without ?: Tandem handles null. '
         'Make it a JsonConverter<${nonNull.getDisplayString()}, '
         '${json.getDisplayString()}>.',
         element: element,
       );

  new notConverter(Element element, {required DartObject value})
    : super(
        'converters: takes JsonConverter<T, S> values of json_annotation, '
        'and ${value.type?.getDisplayString()} is not one.',
        element: element,
      );

  new unnamedJson(
    Element element, {
    required String className,
    required DartType json,
    required String path,
  }) : super(
         '$path: $className writes ${json.getDisplayString()}, which this '
         'library does not import. Import it, so that the generated code can '
         'name it.',
         element: element,
       );

  new converterCycle(
    Element element, {
    required String className,
    required String path,
  }) : super(
         '$path: $className writes a type that converts back into the one it '
         'converts. Make S a type without a converter.',
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
