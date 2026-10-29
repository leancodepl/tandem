import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:tandem_generator/src/agent_generation_error.dart';
import 'package:tandem_generator/src/agent_type_error.dart';
import 'package:tandem_generator/src/agent_types.dart';
import 'package:tandem_generator/src/dart_literal.dart';
import 'package:tandem_generator/src/source_documentation.dart';
import 'package:tandem_generator/src/tokens.dart';

/// A method of the agent list with the source of its parameters' types, as
/// the library writes them.
typedef AgentMethod = ({MethodElement method, List<String> parameterTypes});

final class const AgentMixin({
  required final String className,
  required final List<GetterElement> views,
  required final List<AgentMethod> methods,
}) {
  String generate() {
    final viewCode = _generateList(views.map(_generateView));
    final toolCode = _generateList(methods.map(_generateTool));
    final surfaceDeclaration = _generateSurfaceDeclaration();

    return '''
mixin _\$$className implements AgentSurface {
  @override
  AgentSchema get agentSchema {
$surfaceDeclaration

    return AgentSchema(
      sees: $viewCode,
      calls: $toolCode,
    );
  }
}''';
  }

  static String _generateView(GetterElement getter) {
    final name = getter.displayName;
    final type = AgentTypes(getter).describe(getter.returnType, path: name);
    final agentName = DartLiteral.json(_snakeCase(name));
    final description = DartLiteral.json(_documentation(getter));

    return '''
AgentView.of(() => surface.$name).as(
  $agentName,
  $description,
  $type,
),''';
  }

  static String _generateTool(AgentMethod item) {
    final (:method, :parameterTypes) = item;
    final name = method.displayName;
    final types = AgentTypes(method);
    final parameters = method.formalParameters;
    final parameterCode = [
      for (final (index, parameter) in parameters.indexed)
        _generateParameter(
          parameter,
          types: types,
          typeSource: parameterTypes[index],
        ),
    ].join(Tokens.newLine);
    final arguments = types.constructorArguments(
      parameters,
      from: 'args',
      read: (name) => "args.read('$name')",
    );
    final call = 'surface.$name($arguments)';
    final agentName = DartLiteral.json(_snakeCase(name));
    final description = DartLiteral.json(_documentation(method));
    final invoke = _generateInvocation(method, types: types, call: call);

    return '''
AgentTool(
  surface.$name,
  name: $agentName,
  description: $description,
  parameters: [$parameterCode],
  invoke: $invoke,
),''';
  }

  static String _generateParameter(
    FormalParameterElement parameter, {
    required AgentTypes types,
    required String typeSource,
  }) {
    final name = parameter.displayName;
    final type = parameter.type;

    if (type.isDartCoreList && parameter.isOptionalForAgent) {
      throw AgentTypeError.optionalList(parameter, path: name);
    }

    final typeCode = types.describe(type, path: name);
    final description = switch (documentationOf(parameter)) {
      final text? => ', description: ${DartLiteral.json(text)}',
      null => '',
    };
    final optional = parameter.isOptionalForAgent ? ', required: false' : '';
    final constant = AgentTypes.isConstant(typeCode) ? 'const ' : '';

    return "${constant}AgentParameter<$typeSource>('$name', "
        '$typeCode$description$optional),';
  }

  String _generateSurfaceDeclaration() {
    if (views.isEmpty && methods.isEmpty) return '';

    return '    final surface = this as $className;';
  }

  static String _generateInvocation(
    MethodElement method, {
    required AgentTypes types,
    required String call,
  }) {
    final asyncResultType = _asyncResultType(method);
    final resultType = asyncResultType ?? method.returnType;
    var async = '';
    var invocation = call;

    if (asyncResultType != null) {
      async = 'async ';
      invocation = 'await $call';
    }

    if (resultType is VoidType) {
      return '(args) $async{ $invocation; return null; }';
    }

    final type = types.describe(
      resultType,
      path: 'the result of ${method.displayName}',
    );

    return '''
(args) $async{
  final result = $invocation;

  return AgentResult(result).as($type);
}''';
  }

  static DartType? _asyncResultType(MethodElement method) {
    final type = method.returnType;

    if (type is! InterfaceType) return null;
    if (!type.isDartAsyncFuture && !type.isDartAsyncFutureOr) return null;

    return method.library.typeSystem.flatten(type);
  }

  static String _generateList(Iterable<String> items) {
    if (items.isEmpty) return 'const []';

    final code = items.join(Tokens.newLine);

    return '[$code]';
  }

  static String _documentation(Element element) {
    if (documentationOf(element) case final doc?) {
      return doc;
    }

    throw AgentGenerationError.missingDocumentation(element);
  }

  static String _snakeCase(String name) => name
      .replaceFirst(RegExp('^_+'), '')
      .replaceAllMapped(RegExp('(?<=[a-z0-9])[A-Z]'), (match) => '_${match[0]}')
      .toLowerCase();
}
