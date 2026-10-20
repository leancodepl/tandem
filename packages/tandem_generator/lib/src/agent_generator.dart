import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tandem_generator/src/agent_generation_error.dart';
import 'package:tandem_generator/src/agent_mixin.dart';
import 'package:tandem_generator/src/tokens.dart';

/// Writes the `_$Name` mixin of every class with `@TandemAgent()`, from its
/// `agentCapabilities` getter.
///
/// At runtime the agent list holds only values and tear-offs. The mixin adds
/// what only the source has: the names and doc comments of the listed getters
/// and methods, the JSON Schema of each method's parameters, and the code that
/// reads the arguments and writes values and results as JSON.
class const AgentGenerator() extends Generator {
  static const _tandemAgent = TypeChecker.typeNamedLiterally(
    'TandemAgent',
    inPackage: 'tandem',
  );

  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    final mixins = [
      for (final annotated in library.annotatedWith(_tandemAgent))
        await _generateMixin(annotated.element, buildStep),
    ];

    if (mixins.isEmpty) return null;

    return mixins.join(Tokens.doubleNewLine);
  }

  static Future<String> _generateMixin(
    Element type,
    BuildStep buildStep,
  ) async {
    if (type is! ClassElement) {
      throw AgentGenerationError.notClass(type);
    }

    final reader = _CapabilityReader(type);
    final capabilities = await reader.read(buildStep);

    final mixin = AgentMixin(
      className: type.displayName,
      views: capabilities.views,
      methods: capabilities.methods,
    );

    return mixin.generate();
  }
}

class _CapabilityReader(final ClassElement _type)
    extends RecursiveAstVisitor<void> {
  static const _capability = TypeChecker.typeNamedLiterally(
    'AgentCapability',
    inPackage: 'tandem',
  );

  // In source order: the agent list pairs .sees values with views by place.
  final _viewExpressions = <Expression>[];
  final _methodExpressions = <Expression>[];

  Future<_AgentCapabilities> read(BuildStep buildStep) async {
    final getter = _findCapabilitiesGetter();

    if (getter == null) {
      throw AgentGenerationError.missingCapabilities(_type);
    }

    final source = await buildStep.resolver.astNodeFor(
      getter.firstFragment,
      resolve: true,
    );

    if (source == null) {
      throw AgentGenerationError.missingSource(getter);
    }

    source.accept(this);

    final views = [for (final item in _viewExpressions) _readView(item)];
    final methods = {for (final item in _methodExpressions) _readMethod(item)};

    return _AgentCapabilities(views: views, methods: methods);
  }

  @override
  void visitArgumentList(ArgumentList node) {
    _collectCapability(node);
    super.visitArgumentList(node);
  }

  GetterElement? _findCapabilitiesGetter() {
    final getter = _type.getGetter('agentCapabilities');

    if (getter == null) return null;

    final returnType = getter.returnType;

    if (returnType is! InterfaceType) return null;
    if (!returnType.isDartCoreList) return null;

    final itemType = returnType.typeArguments.single;

    if (!_capability.isExactlyType(itemType)) return null;

    return getter;
  }

  GetterElement _readView(Expression item) {
    if (!_isDirectListItem(item)) {
      throw AgentGenerationError.nestedView(item);
    }

    if (item is! SimpleIdentifier) {
      throw AgentGenerationError.invalidView(item, _type);
    }

    final getter = item.element;

    if (getter is! GetterElement || !getter.isInstanceGetter) {
      throw AgentGenerationError.invalidView(item, _type);
    }

    return getter;
  }

  MethodElement _readMethod(Expression item) {
    if (item is! SimpleIdentifier) {
      throw AgentGenerationError.invalidMethod(item, _type);
    }

    final method = item.element;

    if (method is! MethodElement || !method.isNonGenericInstanceMethod) {
      throw AgentGenerationError.invalidMethod(item, _type);
    }

    return method;
  }

  static bool _isDirectListItem(Expression item) {
    final arguments = item.parent;

    if (arguments is! ArgumentList) return false;

    final capability = arguments.parent;
    final list = capability?.parent;

    if (list is! ListLiteral) return false;

    return list.parent is ExpressionFunctionBody;
  }

  void _collectCapability(ArgumentList node) {
    if (node.arguments.length != 1) return;

    final argument = node.arguments.single;

    if (argument is! Expression) return;

    final constructor = argument.correspondingParameter?.enclosingElement;

    if (constructor is! ConstructorElement) return;

    final isCapability = _capability.isExactly(constructor.enclosingElement);

    if (!isCapability) return;

    final kind = _CapabilityKind.fromName(constructor.name);

    switch (kind) {
      case .sees:
        _viewExpressions.add(argument);
      case .calls || .callsWithApproval:
        _methodExpressions.add(argument);
      case null:
        return;
    }
  }
}

final class const _AgentCapabilities({
  required final List<GetterElement> views,
  required final Set<MethodElement> methods,
});

enum _CapabilityKind() {
  sees,
  calls,
  callsWithApproval;

  static _CapabilityKind? fromName(String? name) {
    if (name == null) return null;

    for (final kind in values) {
      if (kind.name == name) return kind;
    }

    return null;
  }
}

extension on GetterElement {
  bool get isInstanceGetter => !isStatic;
}

extension on MethodElement {
  bool get isNonGenericInstanceMethod => !isStatic && typeParameters.isEmpty;
}
