import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

final class AgentGenerationError extends InvalidGenerationSource {
  new notClass(Element type)
    : super(
        'Put @TandemAgent() on a class: ${type.displayName} is not one.',
        element: type,
      );

  new missingCapabilities(ClassElement type)
    : super(
        'Add @override List<AgentCapability> get agentCapabilities => [...] '
        'to ${type.displayName}, listing what the agent may see and call.',
        element: type,
      );

  new missingSource(ExecutableElement element)
    : super(
        'Tandem cannot find the source of '
        '${element.enclosingElement?.displayName}.${element.displayName}.',
        element: element,
      );

  new missingConverterSource(ClassElement type)
    : super(
        'Tandem cannot find the converters: of ${type.displayName} in its '
        'source. Write them in the annotation.',
        element: type,
      );

  new untypedParameter(FormalParameter parameter)
    : super(
        "Give ${parameter.name?.lexeme} a type: Tandem reads the agent's "
        'arguments as the types the method declares.',
        node: parameter,
      );

  new nestedView(Expression item)
    : super(
        '.sees must be an item of the list after get agentCapabilities =>, '
        'not inside if, for, ?: or a spread. Tandem tells the values apart by '
        'their place in the list. Keep it listed and let the getter return '
        'null when there is nothing to see.',
        node: item,
      );

  new invalidView(Expression item, ClassElement type)
    : super(
        '.sees takes a getter of ${type.displayName}, as in .sees(draft), '
        'so the agent gets its name and doc comment.',
        node: item,
      );

  new invalidMethod(Expression item, ClassElement type)
    : super(
        '.calls takes a method of ${type.displayName} without type parameters, '
        'as in .calls(setQuantity).',
        node: item,
      );

  new missingDocumentation(Element element)
    : super(
        'Add a doc comment to ${element.displayName}: the agent reads it to '
        'know what it is.',
        element: element,
      );
}
