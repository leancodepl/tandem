import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tandem_generator/src/agent_types.dart';

/// Writes the `_$Name` mixin of every class with a
/// `List<AgentCapability> get agent`.
///
/// At runtime the agent list holds only values and tear-offs. The mixin adds
/// what only the source has: the names and doc comments of the getters in
/// `.sees` and how to write their values as JSON, and for every method in
/// `.calls` or `.callsWithApproval` its name, doc comment, the JSON Schema of
/// its parameters, and a typed call that writes the result as JSON.
class const AgentGenerator() extends Generator {
  /// The generator of `tandemBuilder`.
  this;

  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    final mixins = [
      for (final type in library.classes)
        if (_agentGetter(type) case final agent?)
          await _mixin(type, agent, buildStep),
    ];
    return mixins.isEmpty ? null : mixins.join('\n\n');
  }

  static GetterElement? _agentGetter(ClassElement type) {
    final agent = type.getGetter('agent');
    return switch (agent?.returnType) {
      InterfaceType(isDartCoreList: true, typeArguments: [final item])
          when _capability.isExactlyType(item) =>
        agent,
      _ => null,
    };
  }

  static Future<String> _mixin(
    ClassElement type,
    GetterElement agent,
    BuildStep buildStep,
  ) async {
    final name = type.displayName;
    final getter = await buildStep.resolver.astNodeFor(
      agent.firstFragment,
      resolve: true,
    );
    if (getter == null) {
      throw InvalidGenerationSource(
        'Tandem cannot find the source of $name.agent.',
        element: agent,
      );
    }
    final items = _Items();
    getter.accept(items);
    final sees = [for (final item in items.sees) _view(item, name)];
    final methods = {for (final item in items.calls) _method(item, name)};
    return '''
mixin _\$$name implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    ${sees.isEmpty && methods.isEmpty ? '' : 'final surface = this as $name;'}
    return AgentSchema(
      sees: ${_list(sees)},
      calls: ${_list(methods.map(_tool))},
    );
  }
}''';
  }

  static String _view(Expression item, String type) {
    // In `get agent => [.sees(item)]`, item is in the argument list of an
    // invocation, which is an item of the list after =>, not of one inside it.
    final isAgentListItem = switch (item.parent) {
      ArgumentList(
        parent: AstNode(parent: ListLiteral(parent: ExpressionFunctionBody())),
      ) =>
        true,
      _ => false,
    };
    if (!isAgentListItem) {
      throw _error(
        item,
        '.sees must be an item of the list after get agent =>, not inside '
        'if, for, ?: or a spread. Tandem tells the values apart by their '
        'place in the list. Keep it listed and let the getter return null '
        'when there is nothing to see',
      );
    }
    final getter = item is SimpleIdentifier ? item.element : null;
    if (getter is! GetterElement || getter.isStatic) {
      throw _error(
        item,
        '.sees takes a getter of $type, as in .sees(draft), so the agent '
        'gets its name and doc comment',
      );
    }
    final name = getter.displayName;
    final write = AgentTypes(getter).write(getter.returnType, name, name);
    return 'AgentView.of(() => surface.$name, '
        '${dartJsonLiteral(_snakeCase(name))}, '
        '${dartJsonLiteral(_doc(getter))}, ($name) => $write,),';
  }

  static MethodElement _method(Expression item, String type) {
    final method = item is SimpleIdentifier ? item.element : null;
    if (method is! MethodElement ||
        method.isStatic ||
        method.typeParameters.isNotEmpty) {
      throw _error(
        item,
        '.calls takes a method of $type without type parameters, as in '
        '.calls(setQuantity)',
      );
    }
    return method;
  }

  static String _tool(MethodElement method) {
    final name = method.displayName;
    final types = AgentTypes(method);
    final parameters = method.formalParameters;
    final schema = types.object(parameters, '');
    final call = 'surface.$name(${types.arguments(parameters, 'args')})';
    return '''
AgentTool(
  surface.$name,
  name: ${dartJsonLiteral(_snakeCase(name))},
  description: ${dartJsonLiteral(_doc(method))},
  parameters: const ${dartJsonLiteral(schema)},
  invoke: ${_invoke(types, method, call)},
),''';
  }

  /// The `invoke` of an `AgentTool`: makes [call] and writes its result as
  /// JSON, `null` for `void`.
  static String _invoke(AgentTypes types, MethodElement method, String call) {
    final (result, wait) = switch (method.returnType) {
      InterfaceType(isDartAsyncFuture: true, typeArguments: [final value]) ||
      InterfaceType(
        isDartAsyncFutureOr: true,
        typeArguments: [final value],
      ) => (value, 'await '),
      final value => (value, ''),
    };
    final async = wait.isEmpty ? '' : 'async ';
    if (result is VoidType) {
      return '(args) $async{ $wait$call; return null; }';
    }
    final write = types.write(
      result,
      'result',
      'the result of ${method.displayName}',
    );
    return write == 'result'
        ? '(args) => $call'
        : '(args) $async{ final result = $wait$call; return $write; }';
  }

  static String _list(Iterable<String> items) =>
      items.isEmpty ? 'const []' : '[${items.join()}]';

  /// The doc comment of [element] without the slashes. Throws when there is
  /// none: it is all the agent knows about the getter or method.
  static String _doc(Element element) {
    if (documentationOf(element) case final doc?) {
      return doc;
    }
    throw InvalidGenerationSource(
      'Add a doc comment to ${element.displayName}: the agent reads it to '
      'know what it is.',
      element: element,
    );
  }

  static String _snakeCase(String name) => name
      .replaceFirst(RegExp('^_+'), '')
      .replaceAllMapped(RegExp('(?<=[a-z0-9])[A-Z]'), (match) => '_${match[0]}')
      .toLowerCase();

  static InvalidGenerationSource _error(AstNode node, String message) =>
      InvalidGenerationSource('$message.', node: node);
}

const _capability = TypeChecker.typeNamedLiterally(
  'AgentCapability',
  inPackage: 'tandem',
);

/// The arguments of `.sees`, `.calls` and `.callsWithApproval` in an agent
/// list, in source order, however the items are written.
class _Items() extends RecursiveAstVisitor<void> {
  final sees = <Expression>[];
  final calls = <Expression>[];

  @override
  void visitArgumentList(ArgumentList node) {
    if (node.arguments case [final Expression argument]) {
      final constructor = argument.correspondingParameter?.enclosingElement;
      if (constructor is ConstructorElement &&
          _capability.isExactly(constructor.enclosingElement)) {
        (constructor.name == 'sees' ? sees : calls).add(argument);
      }
    }
    super.visitArgumentList(node);
  }
}
