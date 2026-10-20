import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:tandem_generator/src/agent_type_error.dart';

final class const AgentClass._({
  required final InterfaceType type,
  required final ClassElement element,
  required final List<AgentField> fields,
}) {
  static AgentClass? tryRead(
    DartType type, {
    required ExecutableElement source,
    required String path,
  }) {
    if (type is! InterfaceType) return null;

    final element = type.element;

    if (element is! ClassElement) return null;
    if (!element.isPublic || element.library.isInSdk) return null;
    if (type.typeArguments.isNotEmpty) return null;

    final parameters = _readParameters(element, source: source, path: path);
    final fields = [
      for (final parameter in parameters)
        _readField(type, parameter, source: source, path: path),
    ];

    return AgentClass._(type: type, element: element, fields: fields);
  }

  static List<FormalParameterElement> _readParameters(
    ClassElement element, {
    required ExecutableElement source,
    required String path,
  }) {
    final name = element.displayName;
    final constructor = element.unnamedConstructor;

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
    required ExecutableElement source,
    required String path,
  }) {
    final element = type.element;
    final name = parameter.displayName;
    final getter = type.lookUpGetter(name, element.library);

    if (getter == null || getter.isStatic || !parameter.isPublic) {
      throw AgentTypeError.missingGetter(
        source,
        className: element.displayName,
        parameterName: name,
        path: path,
      );
    }

    return (parameter: parameter, getter: getter);
  }
}

typedef AgentField = ({FormalParameterElement parameter, GetterElement getter});

extension on ConstructorElement {
  bool canInstantiate(ClassElement type) =>
      isPublic && (!type.isAbstract || isFactory);
}
