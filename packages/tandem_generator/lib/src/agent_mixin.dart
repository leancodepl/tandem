import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tandem_generator/src/agent_converters.dart';
import 'package:tandem_generator/src/agent_generation_error.dart';
import 'package:tandem_generator/src/agent_names.dart';
import 'package:tandem_generator/src/agent_type_error.dart';
import 'package:tandem_generator/src/agent_types.dart';
import 'package:tandem_generator/src/dart_literal.dart';
import 'package:tandem_generator/src/source_documentation.dart';

/// A method of the agent list with its parameters' types as code of the
/// library of the generated code.
typedef AgentMethod = ({MethodElement method, List<String> parameterTypes});

const _tandemInput = TypeChecker.typeNamedLiterally(
  'TandemInput',
  inPackage: 'tandem',
);

final class const AgentMixin({
  required final String className,

  /// The library of the generated code, which names the types in it.
  required final LibraryElement library,
  required final List<GetterElement> views,
  required final List<AgentMethod> methods,
  required final AgentConverters converters,
}) {
  String generate() {
    final viewCode = _generateList(views.map(_generateView));
    final toolCode = _generateList(methods.map(_generateTool));

    return '''
mixin _\$$className implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as $className;

    return AgentSchema(
      sees: $viewCode,
      calls: $toolCode,
      capabilities: () => surface._\$agentCapabilities,
    );
  }
}''';
  }

  String generateToolNames() {
    // An enum needs a value.
    if (methods.isEmpty) return '';

    final names = [
      for (final (:method, parameterTypes: _) in methods)
        _toolEnumMember(method.displayName),
    ];
    final cases = [
      for (final (:method, parameterTypes: _) in methods)
        _wireNameCase(method.displayName),
    ];

    return '''
/// The names the agent knows the methods of [$className] by.
// `enum $_toolEnum()` needs Dart 3.13 in the app.
// ignore: use_primary_constructors
enum $_toolEnum implements ToolName {
  ${names.join(',\n')};

  @override
  String get value => switch (this) {
    ${cases.join('\n')}
  };

  @override
  String toString() => value;
}''';
  }

  static String toolEnumName(String className) => '${className}Tool';

  /// The member of the enum of [className]'s tool names for [method], with a
  /// trailing underscore also where it is the enum's name or a name that the
  /// enum's code reads.
  static String toolEnumMemberName(String method, {required String className}) {
    final member = enumMemberName(method);
    final isTaken =
        member == toolEnumName(className) ||
        _toolEnumBodyNames.contains(member);

    return isTaken ? '${member}_' : member;
  }

  /// What the enum of [generateToolNames] reads in its body, and what its
  /// `value` switch cannot match as a bare name.
  static const _toolEnumBodyNames = {'String', 'override', 'as', 'when'};

  String get _toolEnum => toolEnumName(className);

  String _toolEnumMember(String method) =>
      toolEnumMemberName(method, className: className);

  String _wireNameCase(String method) =>
      '${_toolEnumMember(method)} => ${DartLiteral.json(agentName(method))},';

  String _generateView(GetterElement getter) {
    final name = getter.displayName;
    final type = AgentTypes(
      getter,
      library: library,
      converters: converters,
    ).describe(getter.returnType, path: name);
    final wireName = DartLiteral.json(agentName(name));
    final description = DartLiteral.json(_documentation(getter));

    return '''
AgentView.of(() => surface.$name).as(
  $wireName,
  $description,
  $type,
),''';
  }

  String _generateTool(AgentMethod item) {
    final (:method, :parameterTypes) = item;
    final name = method.displayName;
    final types = AgentTypes(method, library: library, converters: converters);
    final parameters = method.formalParameters;
    final parameterCode = [
      for (final (index, parameter) in parameters.indexed)
        _generateParameter(
          parameter,
          types: types,
          typeSource: parameterTypes[index],
        ),
    ].join('\n');
    final arguments = types.constructorArguments(
      parameters,
      read: (name) => 'args.read(${DartLiteral.json(name)})',
      readOr: (name, fallback) =>
          'args.readOr(${DartLiteral.json(name)}, $fallback)',
    );
    final call = 'surface.$name($arguments)';
    final description = DartLiteral.json(_documentation(method));
    final invoke = _generateInvocation(method, types: types, call: call);

    return '''
AgentTool(
  surface.$name,
  name: $_toolEnum.${_toolEnumMember(name)},
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
    final input = _tandemInput.hasAnnotationOf(parameter);

    if (input && !AgentTypes.holdsObjects(type)) {
      throw AgentTypeError.inputWithoutObject(parameter, path: name);
    }
    final description = switch (documentationOf(parameter)) {
      final text? => ', description: ${DartLiteral.json(text)}',
      null => '',
    };
    final optional = parameter.isOptionalForAgent ? ', required: false' : '';
    final constant = types.isConstant(type) ? 'const ' : '';
    final inputCode = input ? ', input: true' : '';
    final key = DartLiteral.json(name);

    return '${constant}AgentParameter<$typeSource>($key, '
        '$typeCode$description$optional$inputCode),';
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

    final code = items.join('\n');

    return '[$code]';
  }

  static String _documentation(Element element) {
    if (documentationOf(element) case final doc?) {
      return doc;
    }

    throw AgentGenerationError.missingDocumentation(element);
  }
}
