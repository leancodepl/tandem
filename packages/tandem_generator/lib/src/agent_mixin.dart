import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:tandem_generator/src/agent_generation_error.dart';
import 'package:tandem_generator/src/agent_types.dart';
import 'package:tandem_generator/src/dart_literal.dart';
import 'package:tandem_generator/src/source_documentation.dart';
import 'package:tandem_generator/src/tokens.dart';

final class const AgentMixin({
  required final String className,
  required final List<GetterElement> views,
  required final Set<MethodElement> methods,
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
    final types = AgentTypes(getter);
    final write = types.write(getter.returnType, value: name, path: name);
    final agentName = DartLiteral.json(_snakeCase(name));
    final description = DartLiteral.json(_documentation(getter));

    return '''
AgentView.of(
  () => surface.$name,
  $agentName,
  $description,
  ($name) => $write,
),''';
  }

  static String _generateTool(MethodElement method) {
    final name = method.displayName;
    final types = AgentTypes(method);
    final parameters = types.parameters(method.formalParameters, from: 'args');
    final schema = DartLiteral.json(parameters.schema);
    final arguments = parameters.arguments;
    final call = 'surface.$name($arguments)';
    final agentName = DartLiteral.json(_snakeCase(name));
    final description = DartLiteral.json(_documentation(method));
    final invoke = _generateInvocation(method, types: types, call: call);

    return '''
AgentTool(
  surface.$name,
  name: $agentName,
  description: $description,
  parameters: const $schema,
  invoke: $invoke,
),''';
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
    final asyncResultType = _asyncResultType(method.returnType);
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

    final write = types.write(
      resultType,
      value: 'result',
      path: 'the result of ${method.displayName}',
    );

    if (write == 'result') return '(args) => $call';

    return '''
(args) $async{
  final result = $invocation;

  return $write;
}''';
  }

  static DartType? _asyncResultType(DartType type) {
    if (type is! InterfaceType) return null;
    if (type.isDartAsyncFuture) return type.typeArguments.single;
    if (type.isDartAsyncFutureOr) return type.typeArguments.single;

    return null;
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
