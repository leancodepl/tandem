import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tandem_generator/src/agent_type_operation.dart';

final class AgentTypeError extends InvalidGenerationSource {
  new optionalList(ExecutableElement element, {required String path})
    : super(
        '$path is a list, so the agent must send it: drop the ? and '
        'the default value.',
        element: element,
      );

  new invalidListItem(ExecutableElement element, {required String path})
    : super(
        '$path: the agent sends lists of items that are neither null nor '
        'lists.',
        element: element,
      );

  new unsupported(
    ExecutableElement element, {
    required DartType type,
    required AgentTypeOperation operation,
    required String path,
  }) : super(
         'The agent cannot ${operation.agentVerb} '
         '${type.getDisplayString()} at $path. '
         'It can ${operation.agentVerb} '
         'String, int, double, num, bool, DateTime, enums, '
         'lists and plain classes.',
         element: element,
       );

  new missingConstructor(
    ExecutableElement element, {
    required String className,
    required String path,
  }) : super(
         '$path: Tandem builds $className with its unnamed constructor, '
         'and it has no public one.',
         element: element,
       );

  new emptyConstructor(
    ExecutableElement element, {
    required String className,
    required String path,
  }) : super(
         '$path: Tandem writes $className through its constructor parameters, '
         'and it has none.',
         element: element,
       );

  new positionalParameters(
    ExecutableElement element, {
    required String className,
    required String path,
  }) : super(
         '$path: make the parameters of $className named, so that reordering '
         'them cannot swap values in code generated before.',
         element: element,
       );

  new missingGetter(
    ExecutableElement element, {
    required String className,
    required String parameterName,
    required String path,
  }) : super(
         '$path: Tandem writes $className through the getters named like '
         'its constructor parameters, and it has no getter $parameterName.',
         element: element,
       );

  new recursiveClass(
    ExecutableElement element, {
    required String className,
    required String path,
  }) : super('$path: $className contains itself.', element: element);

  new invalidValueConstructor(
    ExecutableElement element, {
    required String className,
    required DartType valueType,
    required String path,
  }) : super(
         '$path: Tandem builds $className as $className(value), so its unnamed '
         'constructor must be public and take only the value: one positional, '
         'non-null ${valueType.getDisplayString()}.',
         element: element,
       );

  new unsupportedDefault(
    ExecutableElement element, {
    required String parameterName,
  }) : super(
         'Tandem copies only literals, enum values and null as default values. '
         'Make $parameterName required or nullable instead.',
         element: element,
       );
}
