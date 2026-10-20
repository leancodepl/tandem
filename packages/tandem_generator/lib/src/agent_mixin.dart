import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:tandem_generator/src/agent_generation_error.dart';
import 'package:tandem_generator/src/agent_types.dart';
import 'package:tandem_generator/src/tokens.dart';

final class const AgentMixin({
  required final String className,
  required final List<GetterElement> views,
  required final Set<MethodElement> methods,
}) {
  String generate() {
    final viewCode = _list(views.map(_view));
    final toolCode = _list(methods.map(_tool));

    final code = StringBuffer('''
mixin _\$$className implements AgentSurface {
  @override
  AgentSchema get agentSchema {
''');

    if (views.isNotEmpty || methods.isNotEmpty) {
      code
        ..writeln('final surface = this as $className;')
        ..writeln();
    }

    code.write('''
    return AgentSchema(
      sees: $viewCode,
      calls: $toolCode,
    );
  }
}''');

    return code.toString();
  }

  static String _view(GetterElement getter) {
    final name = getter.displayName;
    final write = AgentTypes(getter).write(getter.returnType, name, name);
    final agentName = dartJsonLiteral(_snakeCase(name));
    final description = dartJsonLiteral(_documentation(getter));

    return '''
AgentView.of(
  () => surface.$name,
  $agentName,
  $description,
  ($name) => $write,
),''';
  }

  static String _tool(MethodElement method) {
    final name = method.displayName;
    final types = AgentTypes(method);
    final parameters = method.formalParameters;
    final schema = dartJsonLiteral(types.object(parameters, ''));
    final call = 'surface.$name(${types.arguments(parameters, 'args')})';
    final agentName = dartJsonLiteral(_snakeCase(name));
    final description = dartJsonLiteral(_documentation(method));
    final invoke = _invoke(types, method, call);

    return '''
AgentTool(
  surface.$name,
  name: $agentName,
  description: $description,
  parameters: const $schema,
  invoke: $invoke,
),''';
  }

  static String _invoke(AgentTypes types, MethodElement method, String call) {
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
      'result',
      'the result of ${method.displayName}',
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

  static String _list(Iterable<String> items) {
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
