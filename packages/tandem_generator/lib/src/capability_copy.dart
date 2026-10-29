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
  final _prefixed = <Token, String>{};

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
    body.accept(_StaticMembers(_type, _prefixed));

    final copy = _copy(body);
    final name = _type.displayName;
    final parameters = _type.typeParameters.map((p) => p.displayName);
    final typeArguments = parameters.isEmpty
        ? ''
        : '<${parameters.join(', ')}>';
    return '''
extension$typeArguments on $name$typeArguments {
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

      code
        ..write(_prefixed[token] ?? '')
        ..write(_replaced[token] ?? token.lexeme);
      previous = token;
    }

    return '$code';
  }
}

/// Qualifies the static members of the class, which an extension does not
/// see by their bare names.
final class _StaticMembers(
  final ClassElement _type,
  final Map<Token, String> _prefixed,
) extends RecursiveAstVisitor<void> {
  @override
  void visitSuperExpression(SuperExpression node) =>
      throw AgentGenerationError.superInCapabilities(node);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    final member = switch (element) {
      PropertyAccessorElement(:final variable) => variable,
      _ => element,
    };
    final isStaticMember = switch (member) {
      FieldElement(isStatic: true, :final enclosingElement) =>
        enclosingElement == _type,
      MethodElement(isStatic: true, :final enclosingElement) =>
        enclosingElement == _type,
      _ => false,
    };

    if (isStaticMember && !node.hasTarget) {
      _prefixed[node.token] = '${_type.displayName}.';
    }
  }
}

extension on SimpleIdentifier {
  bool get hasTarget => switch (parent) {
    PrefixedIdentifier(:final identifier) => identifier == this,
    PropertyAccess(:final propertyName) => propertyName == this,
    MethodInvocation(:final methodName, :final target) =>
      methodName == this && target != null,
    _ => false,
  };
}
