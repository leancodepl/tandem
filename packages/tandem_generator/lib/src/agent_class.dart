import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:tandem_generator/src/agent_type_error.dart';

/// A class that Tandem reads through its unnamed constructor, with a getter
/// of the same type for each parameter. A generic class is read with its type
/// arguments, so `Page<Customer>` and `Page<Order>` are two types.
final class const AgentClass._(final List<AgentField> fields) {
  /// Throws an [AgentTypeError] when [type] is not such a class.
  static AgentClass read(
    InterfaceType type, {
    required Element source,
    required String path,
  }) {
    final element = type.element;

    if (element is! ClassElement ||
        !element.isPublic ||
        element.isFrameworkType ||
        type.typeArguments.any((argument) => argument is TypeParameterType)) {
      throw AgentTypeError.unsupported(source, type: type, path: path);
    }

    final parameters = _readParameters(type, source: source, path: path);
    final fields = [
      for (final parameter in parameters)
        _readField(type, parameter, source: source, path: path),
    ];

    return ._(fields);
  }

  static List<FormalParameterElement> _readParameters(
    InterfaceType type, {
    required Element source,
    required String path,
  }) {
    final element = type.element;
    final name = element.displayName;
    final constructor = type.constructors
        .where((constructor) => constructor.name == 'new')
        .firstOrNull;

    if (constructor == null || !constructor.canInstantiate(element)) {
      throw AgentTypeError.missingConstructor(
        source,
        className: name,
        path: path,
      );
    }

    final parameters = constructor.formalParameters;

    if (parameters.isEmpty) {
      throw AgentTypeError.emptyConstructor(
        source,
        className: name,
        path: path,
      );
    }

    final positionalCount = parameters.where((p) => p.isPositional).length;

    if (positionalCount > 1) {
      throw AgentTypeError.positionalParameters(
        source,
        className: name,
        path: path,
      );
    }

    return parameters;
  }

  static AgentField _readField(
    InterfaceType type,
    FormalParameterElement parameter, {
    required Element source,
    required String path,
  }) {
    final name = parameter.displayName;
    final getter = type.getGetter(name);

    if (getter == null || getter.isStatic || !parameter.isPublic) {
      throw AgentTypeError.missingGetter(
        source,
        className: type.element.displayName,
        parameterName: name,
        path: path,
      );
    }

    if (getter.returnType != parameter.type) {
      throw AgentTypeError.getterType(
        source,
        className: type.element.displayName,
        parameterName: name,
        path: path,
      );
    }

    return (parameter: parameter, getter: getter);
  }
}

typedef AgentField = ({FormalParameterElement parameter, GetterElement getter});

extension AgentClasses on DartType {
  /// Whether [AgentClass.read] reads this type. The agent points at a value
  /// of it by path, or writes one with `@TandemInput()`, also when a
  /// converter gives it a form.
  bool get isAgentClass {
    final type = this;
    if (type is! InterfaceType) return false;

    try {
      AgentClass.read(type, source: type.element, path: '');
    } on AgentTypeError {
      return false;
    }

    return true;
  }
}

extension on ConstructorElement {
  bool canInstantiate(InterfaceElement type) =>
      isPublic && (type is! ClassElement || !type.isAbstract || isFactory);
}

extension on InterfaceElement {
  /// A type of Dart or Flutter, such as `Duration` or `IconData`: its values
  /// have a form only through a converter.
  bool get isFrameworkType {
    final uri = library.uri;

    return uri.isScheme('dart') ||
        (uri.isScheme('package') && uri.pathSegments.first == 'flutter');
  }
}
