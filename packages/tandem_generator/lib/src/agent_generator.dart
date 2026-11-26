import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tandem_generator/src/agent_converters.dart';
import 'package:tandem_generator/src/agent_generation_error.dart';
import 'package:tandem_generator/src/agent_mixin.dart';
import 'package:tandem_generator/src/agent_names.dart';
import 'package:tandem_generator/src/capability_copy.dart';
import 'package:tandem_generator/src/mixin_generator.dart';
import 'package:tandem_generator/src/type_names.dart';

/// Writes the `_$Name` mixin of every class with `@TandemAgent()`, from its
/// `agentCapabilities` getter.
///
/// At runtime the agent list holds only values and tear-offs. The mixin adds
/// what only the source has: the names and doc comments of the listed getters
/// and methods, the JSON Schema of each method's parameters, and the code that
/// reads the arguments and writes values and results as JSON.
class const AgentGenerator() extends MixinGenerator {
  this : super('TandemAgent');

  @override
  Future<String> generateMixin(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) {
      throw AgentGenerationError.notClass(element);
    }

    final reader = _CapabilityReader(element);
    final capabilities = await reader.read(buildStep);
    final converters = await AgentConverters.read(
      annotation,
      element,
      listName: '_\$${element.displayName}Converters',
      buildStep: buildStep,
    );

    final mixin = AgentMixin(
      className: element.displayName,
      library: element.library,
      views: capabilities.views,
      methods: capabilities.methods,
      converters: converters,
    );

    return [
      mixin.generate(),
      mixin.generateToolNames(),
      capabilities.copy,
      converters.declaration,
    ].join('\n\n');
  }
}

class _CapabilityReader(final ClassElement _type)
    extends RecursiveAstVisitor<void> {
  static const _capability = TypeChecker.typeNamedLiterally(
    'AgentCapability',
    inPackage: 'tandem',
  );

  late final _copy = CapabilityCopy(_type);
  final _views = <GetterElement>{};
  final _methods = <MethodElement>{};

  Future<_AgentCapabilities> read(BuildStep buildStep) async {
    final getter = _findCapabilitiesGetter();

    if (getter == null) {
      throw AgentGenerationError.missingCapabilities(_type);
    }

    final source = await buildStep.resolver.astNodeFor(
      getter.firstFragment,
      resolve: true,
    );

    if (source is! MethodDeclaration) {
      if (getter.isOriginVariable) {
        throw AgentGenerationError.capabilitiesField(_type);
      }

      throw AgentGenerationError.missingSource(getter);
    }

    source.accept(this);

    _checkCapabilityNames();

    return _AgentCapabilities(
      views: [..._views],
      copy: _copy.generate(source.body),
      methods: [
        for (final method in _methods)
          (
            method: method,
            parameterTypes: await _parameterTypes(method, buildStep),
          ),
      ],
    );
  }

  @override
  void visitArgumentList(ArgumentList node) {
    _readCapability(node);
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
    if (item is! SimpleIdentifier) {
      throw AgentGenerationError.invalidView(item, _type);
    }

    final getter = item.element;

    if (getter is! GetterElement || getter.isStatic) {
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

    final methodName = method.displayName;
    final wireName = agentName(methodName);

    if (wireName.startsWith(tandemToolPrefix)) {
      throw AgentGenerationError.reservedName(item, name: wireName);
    }

    return method;
  }

  void _checkCapabilityNames() {
    _checkNameCollisions(
      _views,
      nameOf: agentName,
      collisionError: AgentGenerationError.sameAgentName,
    );
    _checkNameCollisions(
      _methods,
      nameOf: agentName,
      collisionError: AgentGenerationError.sameAgentName,
    );
    _checkNameCollisions(
      _methods,
      nameOf: toolEnumMemberName,
      collisionError: AgentGenerationError.sameToolEnumMemberName,
    );
  }

  void _checkNameCollisions(
    Iterable<ExecutableElement> elements, {
    required String Function(String displayName) nameOf,
    required _NameCollisionError collisionError,
  }) {
    final byName = <String, ExecutableElement>{};

    for (final element in elements) {
      final name = nameOf(element.displayName);

      if (byName[name] case final other?
          when other.baseElement != element.baseElement) {
        throw collisionError(name, first: other, second: element);
      }

      byName[name] = element;
    }
  }

  /// The type of each parameter of [method] as code of the class's library:
  /// as the declaration writes it when the method is in that library, which
  /// also covers types that [TypeNames] cannot name, such as function types.
  /// The types of a method of a generic superclass are named too, since they
  /// hold type arguments where the declaration writes type parameters.
  Future<List<String>> _parameterTypes(
    MethodElement method,
    BuildStep buildStep,
  ) async {
    if (method.library != _type.library || method.hasSubstitutedParameters) {
      return _namedParameterTypes(method);
    }

    final source = await buildStep.resolver.astNodeFor(method.firstFragment);

    if (source is! MethodDeclaration) {
      throw AgentGenerationError.missingSource(method);
    }

    return [
      for (final parameter
          in source.parameters?.parameters ?? const <FormalParameter>[])
        switch (parameter) {
          FormalParameter(:final type?, functionTypedSuffix: null) =>
            type.toSource(),
          _ => throw AgentGenerationError.untypedParameter(parameter),
        },
    ];
  }

  List<String> _namedParameterTypes(MethodElement method) {
    final names = TypeNames(_type.library);

    return [
      for (final parameter in method.formalParameters)
        switch (names.name(parameter.type)) {
          final name? => name,
          null => throw AgentGenerationError.unnamedParameterType(
            _type,
            method: method,
            parameter: parameter,
          ),
        },
    ];
  }

  void _readCapability(ArgumentList node) {
    if (node.arguments.length != 1) return;

    final argument = node.arguments.single;

    if (argument is! Expression) return;

    final constructor = argument.correspondingParameter?.enclosingElement;

    if (constructor is! ConstructorElement) return;

    final isCapability = _capability.isExactly(constructor.enclosingElement);

    if (!isCapability) return;

    switch (constructor.name) {
      case 'sees':
        final view = _readView(argument);
        _views.add(view);
        _copy.nameView(argument, agentName: agentName(view.displayName));
      case 'calls' || 'callsWithApproval':
        _methods.add(_readMethod(argument));
    }
  }
}

typedef _NameCollisionError = AgentGenerationError Function(
  String name, {
  required ExecutableElement first,
  required ExecutableElement second,
});

final class const _AgentCapabilities({
  required final List<GetterElement> views,

  /// The extension with the copy of the list that names each `.sees`.
  required final String copy,
  required final List<AgentMethod> methods,
});

extension on MethodElement {
  bool get isNonGenericInstanceMethod => !isStatic && typeParameters.isEmpty;

  bool get hasSubstitutedParameters => formalParameters.any(
    (parameter) => parameter.type != parameter.baseElement.type,
  );
}
