import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tandem_generator/src/agent_class.dart';
import 'package:tandem_generator/src/agent_type_error.dart';
import 'package:tandem_generator/src/agent_type_operation.dart';
import 'package:tandem_generator/src/dart_literal.dart';
import 'package:tandem_generator/src/source_documentation.dart';

part 'agent_parameters.dart';
part 'type_helpers/type_helper.dart';
part 'type_helpers/scalar_helpers.dart';
part 'type_helpers/list_helper.dart';
part 'type_helpers/object_helper.dart';

final class AgentTypes(final ExecutableElement _element) {
  final _visitingClasses = <ClassElement>{};

  GeneratedParameters parameters(
    List<FormalParameterElement> parameters, {
    required String from,
  }) {
    final reader = _AgentParameters(this);
    final schema = reader.schema(parameters, prefix: '');
    final arguments = reader.arguments(parameters, from: from);

    return (schema: schema, arguments: arguments);
  }

  String write(DartType type, {required String value, required String path}) {
    var valueType = type;

    if (type.isNullable) {
      valueType = _element.library.typeSystem.promoteToNonNull(type);
    }

    final helper = _helperFor(valueType, operation: .write, path: path);

    if (type.isNullable) {
      return helper.writeNullable(this, value: value, path: path);
    }

    return helper.write(this, value: value, path: path);
  }

  _TypeHelper _helperFor(
    DartType type, {
    required AgentTypeOperation operation,
    required String path,
  }) {
    final primitive = _PrimitiveHelper.tryFromDartType(type);

    if (primitive != null) return primitive;

    if (type is InterfaceType) {
      final element = type.element;

      if (type.isDateTime) return const _DateTimeHelper();

      if (element is EnumElement) return _EnumHelper(element);

      if (element is ExtensionTypeElement) {
        final representation = _PrimitiveHelper.tryFromDartType(
          type.extensionTypeErasure,
        );

        if (representation != null) {
          return _ExtensionHelper(type, element, representation);
        }
      }

      if (type.isDartCoreList) return _ListHelper(type.typeArguments.single);
      if (element is ClassElement) return _ObjectHelper(type);
    }

    throw AgentTypeError.unsupported(
      _element,
      type: type,
      operation: operation,
      path: path,
    );
  }

  T _withPlainClass<T>(
    InterfaceType type, {
    required AgentTypeOperation operation,
    required String path,
    required T Function(AgentClass object) body,
  }) {
    final object = AgentClass.tryRead(type, source: _element, path: path);

    if (object == null) {
      throw AgentTypeError.unsupported(
        _element,
        type: type,
        operation: operation,
        path: path,
      );
    }

    final element = object.element;

    if (!_visitingClasses.add(element)) {
      throw AgentTypeError.recursiveClass(
        _element,
        className: element.displayName,
        path: path,
      );
    }

    try {
      return body(object);
    } finally {
      _visitingClasses.remove(element);
    }
  }
}

extension on DartType {
  static const _dateTime = TypeChecker.typeNamed(
    DateTime,
    inPackage: 'core',
    inSdk: true,
  );

  bool get isNullable => nullabilitySuffix != .none;

  bool get isDateTime => _dateTime.isExactlyType(this);
}
