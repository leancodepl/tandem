import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tandem_generator/src/agent_names.dart';

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

  new capabilitiesField(ClassElement type)
    : super(
        'Make agentCapabilities of ${type.displayName} a getter, as in '
        'List<AgentCapability> get agentCapabilities => [...]. Tandem reads '
        'the list through a copy of its body, and a field has none.',
        element: type,
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

  new unnamedParameterType(
    ClassElement type, {
    required MethodElement method,
    required FormalParameterElement parameter,
  }) : super(
         '${method.displayName}.${parameter.displayName}: import '
         '${parameter.type.getDisplayString()} where ${type.displayName} is, '
         'so that the generated code can name it.',
         element: type,
       );

  new superInCapabilities(SuperExpression node)
    : super(
        'agentCapabilities cannot use super: Tandem reads the list through a '
        'copy of it in an extension. Call a method of the class instead.',
        node: node,
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

  new sameAgentName(
    String name, {
    required ExecutableElement first,
    required ExecutableElement second,
  }) : this._nameCollision(first, second, 'the agent knows both as $name.');

  new reservedName(Expression item, {required String name})
    : super(
        'Rename $item: the agent knows it as $name, and the tools that start '
        'with $tandemToolPrefix are those Tandem offers itself.',
        node: item,
      );

  new sameToolEnumMemberName(
    String memberName, {
    required ExecutableElement first,
    required ExecutableElement second,
  }) : this._nameCollision(
         first,
         second,
         'both would be $memberName in the enum of tool names.',
       );

  new missingDocumentation(Element element)
    : super(
        'Add a doc comment to ${element.displayName}: the agent reads it to '
        'know what it is.',
        element: element,
      );

  new _nameCollision(
    ExecutableElement first,
    ExecutableElement second,
    String explanation,
  ) : super(
        'Rename ${first.displayName} or ${second.displayName}: $explanation',
        element: second,
      );
}
