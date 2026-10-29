import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:tandem_generator/src/agent_generation_error.dart';

/// A copy of the body of `agentCapabilities` in which each `.sees(order)` is
/// `.seesAs('order', order)`, for an extension on the surface's class. Tandem
/// reads the list through it, so every value it sees carries the name of
/// its getter, also when the list depends on the route.
final class CapabilityCopy(final ClassElement _type) {
  final _replaced = <Token, String>{};

  /// Gives [item], the argument of a `.sees`, the [agentName] of its getter.
  void nameView(Expression item, {required String agentName}) {
    final arguments = item.parent;

    if (arguments is! ArgumentList) return;

    final constructor = arguments.leftParenthesis.previous;

    if (constructor == null || constructor.lexeme != 'sees') return;

    _replaced[constructor] = 'seesAs';
    _replaced[arguments.leftParenthesis] = "('$agentName', ";
  }

  /// The extension with the copy of [body].
  String generate(FunctionBody body) {
    body.accept(_QualifiedMembers(_type, _replaced));

    final copy = _copy(body);
    final name = _type.displayName;
    final typeParameters = body
        .thisOrAncestorOfType<ClassDeclaration>()
        ?.namePart
        .typeParameters;
    final declaration = typeParameters?.toSource() ?? '';
    final typeArguments = switch (typeParameters?.typeParameters) {
      final parameters? =>
        '<${parameters.map((p) => p.name.lexeme).join(', ')}>',
      null => '',
    };
    return '''
extension$declaration on $name$typeArguments {
  List<AgentCapability> get _\$agentCapabilities $copy
}''';
  }

  String _copy(FunctionBody body) {
    final code = StringBuffer();
    Token? previous;

    for (
      Token? token = body.beginToken;
      token != null;
      token = token == body.endToken ? null : token.next
    ) {
      if (previous != null && previous.end != token.offset) code.write(' ');

      code.write(_replaced[token] ?? token.lexeme);
      previous = token;
    }

    return '$code';
  }
}

/// Qualifies the members of the class that the body names bare, as the
/// extension does not see them the way the class does: it sees no static
/// member by its bare name, and a name of the library hides an instance
/// member.
final class _QualifiedMembers(
  final ClassElement _type,
  final Map<Token, String> _replaced,
) extends RecursiveAstVisitor<void> {
  late final _libraryScope = _type.library.firstFragment.scope;

  @override
  void visitSuperExpression(SuperExpression node) =>
      throw AgentGenerationError.superInCapabilities(node);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.hasTarget) return;

    final qualifier = _qualifier(node);

    if (qualifier == null) return;

    final name = node.name;
    final interpolation = node.parent;
    final inSimpleInterpolation =
        interpolation is InterpolationExpression &&
        interpolation.rightBracket == null;

    _replaced[node.token] = inSimpleInterpolation
        ? '{$qualifier.$name}'
        : '$qualifier.$name';
  }

  String? _qualifier(SimpleIdentifier node) {
    final member = switch (node.element) {
      PropertyAccessorElement(:final variable) => variable,
      final element => element,
    };

    final (isStatic, owner) = switch (member) {
      FieldElement(:final isStatic, :final enclosingElement) => (
        isStatic,
        enclosingElement,
      ),
      MethodElement(:final isStatic, :final enclosingElement) => (
        isStatic,
        enclosingElement,
      ),
      _ => (false, null),
    };

    if (isStatic && owner == _type) return _type.displayName;

    if (!isStatic && owner is InstanceElement && _isLibraryName(node.name)) {
      return 'this';
    }

    return null;
  }

  bool _isLibraryName(String name) {
    final result = _libraryScope.lookup(name);

    return result.getter != null || result.setter != null;
  }
}

extension on SimpleIdentifier {
  bool get hasTarget => switch (parent) {
    PrefixedIdentifier(:final identifier) => identifier == this,
    PropertyAccess(:final propertyName) => propertyName == this,
    MethodInvocation(:final methodName, :final target, :final isCascaded) =>
      methodName == this && (target != null || isCascaded),
    DotShorthandPropertyAccess(:final propertyName) => propertyName == this,
    DotShorthandInvocation(:final memberName) => memberName == this,
    _ => false,
  };
}
