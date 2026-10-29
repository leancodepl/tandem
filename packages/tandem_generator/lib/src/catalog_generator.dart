import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tandem_generator/src/agent_converters.dart';
import 'package:tandem_generator/src/agent_type_error.dart';
import 'package:tandem_generator/src/agent_types.dart';
import 'package:tandem_generator/src/catalog_error.dart';
import 'package:tandem_generator/src/dart_literal.dart';
import 'package:tandem_generator/src/source_documentation.dart';
import 'package:tandem_generator/src/tokens.dart';
import 'package:tandem_generator/src/type_names.dart';

/// Writes the `_$Name` mixin of every class with `@TandemCatalog([...])`: an
/// `AgentCatalog` whose components are the listed widgets, read from their
/// constructors and doc comments.
class const CatalogGenerator() extends Generator {
  static const _tandemCatalog = TypeChecker.typeNamedLiterally(
    'TandemCatalog',
    inPackage: 'tandem',
  );

  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    final mixins = [
      for (final annotated in library.annotatedWith(_tandemCatalog))
        await _generateMixin(
          annotated.element,
          annotated.annotation,
          buildStep,
        ),
    ];

    if (mixins.isEmpty) return null;

    return mixins.join(Tokens.doubleNewLine);
  }

  static Future<String> _generateMixin(
    Element type,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (type is! ClassElement) throw CatalogError.notClass(type);

    final className = type.displayName;
    final converters = await AgentConverters.read(
      annotation,
      type,
      listName: '_\$${className}Converters',
      buildStep: buildStep,
    );
    final widgets = [
      for (final value in annotation.read('components').listValue)
        _widgetOf(value.toTypeValue(), catalog: type),
    ];
    _checkNames(widgets, catalog: type);
    final components = [
      for (final widget in widgets)
        _Component(widget, catalog: type, converters: converters),
    ];
    final documentation = _CatalogDocumentation.of(type);
    _checkExample(documentation.example, components, catalog: type);

    final componentCode = components.map((c) => c.generate()).join();
    final guidelines = DartLiteral.json(documentation.guidelines);
    final example = DartLiteral.json(documentation.example);

    final mixin =
        '''
mixin _\$$className implements AgentCatalog {
  @override
  String get guidelines => $guidelines;

  @override
  List<Map<String, Object?>> get example => const $example;

  @override
  List<AgentComponent> get components => [$componentCode];
}''';

    return [mixin, converters.declaration].join(Tokens.doubleNewLine);
  }

  static InterfaceType _widgetOf(
    DartType? type, {
    required ClassElement catalog,
  }) {
    if (type is InterfaceType &&
        type.element is ClassElement &&
        type.allSupertypes.any(_isWidget)) {
      return type;
    }

    throw CatalogError.notWidget(catalog, type: type);
  }

  /// Checks that no two widgets have the name the agent knows them by.
  static void _checkNames(
    List<InterfaceType> widgets, {
    required ClassElement catalog,
  }) {
    final byName = <String, InterfaceType>{};

    for (final widget in widgets) {
      final name = widget.element.displayName;

      if (byName[name] case final other?) {
        throw CatalogError.sameName(
          catalog,
          name: name,
          first: AgentTypes.idOf(other),
          second: AgentTypes.idOf(widget),
        );
      }

      byName[name] = widget;
    }
  }

  /// Checks the names in the example against the catalog. Paths and methods
  /// depend on the screen, which `TandemView` checks in debug.
  static void _checkExample(
    List<Map<String, Object?>> example,
    List<_Component> components, {
    required ClassElement catalog,
  }) {
    final byName = {for (final c in components) c.name: c};

    for (final component in example) {
      final id = component['id'];
      final name = component['component'];
      final found = byName[name];

      if (id is! String || name is! String || found == null) {
        throw CatalogError.exampleComponent(
          catalog,
          id: '$id',
          name: '$name',
          names: byName.keys,
        );
      }

      for (final key in component.keys) {
        if (key == 'id' || key == 'component') continue;

        if (!found.propertyNames.contains(key)) {
          throw CatalogError.exampleProperty(
            catalog,
            id: id,
            component: name,
            property: key,
            properties: found.propertyNames,
          );
        }
      }
    }
  }
}

/// One widget of the catalog and the properties the agent may set.
final class _Component(
  final InterfaceType _widget, {
  required final ClassElement catalog,
  required final AgentConverters converters,
}) {
  late final _element = _widget.element;
  late final _types = AgentTypes(
    catalog,
    library: catalog.library,
    converters: converters,
  );
  late final _names = TypeNames(catalog.library);
  late final _typeSystem = _element.library.typeSystem;
  late final _parameters = _readParameters();

  String get name => _element.displayName;

  Iterable<String> get propertyNames => [
    for (final parameter in _parameters)
      if (parameter.code case _?) parameter.element.displayName,
  ];

  String generate() {
    final widgetName = _names.name(_widget);

    if (widgetName == null) {
      throw CatalogError.unnamedWidget(_element);
    }

    final description = DartLiteral.json(_description());
    final properties = [
      for (final parameter in _parameters)
        if (parameter.code case final code?) '$code,',
    ].join();
    final arguments = [
      for (final parameter in _parameters)
        if (parameter.argument case final argument?) '$argument,',
    ].join();

    return '''
AgentComponent<$widgetName>.of(
  name: ${DartLiteral.json(name)},
  description: $description,
  properties: (property) => [$properties],
  build: (args) => $widgetName($arguments),
),''';
  }

  String _description() {
    final documentation = documentationOf(_element);

    if (documentation == null) {
      throw CatalogError.missingDocumentation(_element);
    }

    return documentation.split('\n\n').first;
  }

  List<_Parameter> _readParameters() {
    final constructor = _widget.constructors
        .where((constructor) => constructor.name == 'new')
        .firstOrNull;

    if (constructor == null || !constructor.isPublic) {
      throw CatalogError.missingConstructor(_element);
    }

    final parameters = [
      for (final parameter in constructor.formalParameters)
        _readParameter(parameter),
    ];
    final skippedPositional = parameters.indexWhere(
      (p) => p.element.isPositional && p.argument == null,
    );
    final laterPositional = parameters.lastIndexWhere(
      (p) => p.element.isPositional && p.argument != null,
    );

    if (skippedPositional != -1 && skippedPositional < laterPositional) {
      throw CatalogError.skippedPositional(
        _element,
        parameter: parameters[skippedPositional].element.displayName,
      );
    }

    return parameters;
  }

  _Parameter _readParameter(FormalParameterElement parameter) {
    final name = parameter.displayName;
    final type = parameter.type;
    final path = '${_element.displayName}.$name';
    final nullable = type.nullabilitySuffix != .none;
    final optional = nullable || parameter.hasDefaultValue;
    final requiredCode = optional ? ', required: false' : '';

    final nonNull = _typeSystem.promoteToNonNull(type);

    if (_isInfrastructure(type)) {
      if (!optional) {
        throw CatalogError.noForm(
          _element,
          parameter: parameter,
          converted: nonNull,
        );
      }
      return _Parameter.skipped(parameter);
    }

    if (_widgetClass.isExactlyType(nonNull)) {
      return _Parameter(
        parameter,
        code: "property.child('$name'$requiredCode)",
        read: nullable ? "args.childOrNull('$name')" : "args.child('$name')",
      );
    }

    if (type
        case InterfaceType(isDartCoreList: true, typeArguments: [final item])
        when _widgetClass.isExactlyType(item) &&
            item.nullabilitySuffix == .none) {
      return _Parameter(
        parameter,
        code: "property.children('$name'$requiredCode)",
        read: "args.children('$name')",
      );
    }

    if (_holdsWidget(nonNull)) {
      if (!optional) {
        throw CatalogError.childType(_element, parameter: parameter);
      }
      log.warning(CatalogError.childTypeMessage(_element, parameter));
      return _Parameter.skipped(parameter);
    }

    if (type
        case FunctionType(
          returnType: VoidType(),
          formalParameters: final inputs,
        )
        when inputs.length <= 1 &&
            inputs.every((p) => p.isRequiredPositional)) {
      return _callback(parameter, inputs: inputs);
    }

    return _value(parameter, path: path, optional: optional);
  }

  /// An action, which the component needs unless it is nullable: a default
  /// callback is no action of the screen.
  _Parameter _callback(
    FormalParameterElement parameter, {
    required List<FormalParameterElement> inputs,
  }) {
    final name = parameter.displayName;
    final nullable = parameter.type.nullabilitySuffix != .none;
    final requiredCode = nullable ? ', required: false' : '';

    if (inputs case [final input]) {
      final String typeCode;
      try {
        typeCode = _types.describe(input.type, path: '$name()');
      } on AgentTypeError {
        if (nullable) {
          log.warning(CatalogError.noFormMessage(_element, parameter));
          return _Parameter.skipped(parameter);
        }
        throw CatalogError.noForm(
          _element,
          parameter: parameter,
          converted: _typeSystem.promoteToNonNull(input.type),
        );
      }
      final callbackType = _typeSystem.promoteToNonNull(parameter.type);
      final anchor = switch (_getterType(name)) {
        final type? when _typeSystem.promoteToNonNull(type) == callbackType =>
          "property.field('$name', (widget) => widget.$name)",
        _ => switch (_names.name(input.type)) {
          final typeName? => "property.field<$typeName>('$name')",
          null => throw CatalogError.unnamedType(
            _element,
            parameter: parameter,
          ),
        },
      };
      return _Parameter(
        parameter,
        code: '$anchor.as($typeCode$requiredCode)',
        read: nullable ? "args.fieldOrNull('$name')" : "args.field('$name')",
      );
    }

    return _Parameter(
      parameter,
      code: "property.press('$name'$requiredCode)",
      read: nullable ? "args.pressOrNull('$name')" : "args.press('$name')",
    );
  }

  _Parameter _value(
    FormalParameterElement parameter, {
    required String path,
    required bool optional,
  }) {
    final name = parameter.displayName;
    final String typeCode;

    try {
      typeCode = _types.describe(parameter.type, path: path);
    } on AgentTypeError {
      if (optional) {
        log.warning(CatalogError.noFormMessage(_element, parameter));
        return _Parameter.skipped(parameter);
      }
      throw CatalogError.noForm(
        _element,
        parameter: parameter,
        converted: _typeSystem.promoteToNonNull(parameter.type),
      );
    }

    final ({String? code})? fallback;
    try {
      fallback = _types.copyDefault(parameter, path: path);
    } on AgentTypeError catch (error) {
      log.warning(error.message);
      return _Parameter.skipped(parameter);
    }

    if (parameter.hasDefaultValue && fallback == null) {
      log.warning(
        '$path keeps its default: Tandem copies only literals, enum values '
        "and the static const members of the value's class.",
      );
      return _Parameter.skipped(parameter);
    }

    final anchor = switch (_getterType(name)) {
      final type? when type == parameter.type =>
        "property('$name', (widget) => widget.$name)",
      _ => switch (_names.name(parameter.type)) {
        final typeName? => "property<$typeName>('$name')",
        null => throw CatalogError.unnamedType(_element, parameter: parameter),
      },
    };
    final requiredCode = optional ? ', required: false' : '';

    return _Parameter(
      parameter,
      code: '$anchor.value($typeCode$requiredCode)',
      read: "args.value('$name')",
      fallback: fallback,
    );
  }

  /// The type of the widget's public getter [name], which types the
  /// property when it is the parameter's type.
  DartType? _getterType(String name) =>
      switch (_widget.lookUpGetter(name, _element.library)) {
        GetterElement(isPublic: true, :final returnType) => returnType,
        _ => null,
      };

  static bool _isInfrastructure(DartType type) => switch (type) {
    InterfaceType(:final element) =>
      _key.isAssignableFromType(type) ||
          _focusNode.isAssignableFromType(type) ||
          (element is ClassElement &&
              _changeNotifier.isAssignableFromType(type)),
    _ => false,
  };

  static const _key = TypeChecker.typeNamedLiterally(
    'Key',
    inPackage: 'flutter',
  );
  static const _focusNode = TypeChecker.typeNamedLiterally(
    'FocusNode',
    inPackage: 'flutter',
  );
  static const _changeNotifier = TypeChecker.typeNamedLiterally(
    'ChangeNotifier',
    inPackage: 'flutter',
  );
}

/// A parameter of a widget's constructor: its property code and the
/// argument that reads it, or neither when the agent cannot set it.
final class const _Parameter(
  final FormalParameterElement element, {
  final String? code,
  final String? read,
  final ({String? code})? fallback,
}) {
  /// A required parameter gets null, which its type allows, as Dart cannot
  /// leave it out.
  new skipped(FormalParameterElement element)
    : this(element, read: element.isOptional ? null : 'null');

  String? get argument {
    final value = switch ((read, fallback)) {
      (_?, (code: final defaultCode?)) =>
        "args.valueOr('${element.displayName}', $defaultCode)",
      (final read?, _) => read,
      (null, _) => null,
    };

    if (value == null) return null;

    return element.isNamed ? '${element.displayName}: $value' : value;
  }
}

/// The guidelines and the example of a catalog's doc comment.
final class const _CatalogDocumentation._(
  final String guidelines,
  final List<Map<String, Object?>> example,
) {
  factory of(ClassElement catalog) {
    final raw = catalog.documentationComment;

    if (raw == null) throw CatalogError.missingDocumentation(catalog);

    final text = raw
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^\s*/// ?'), ''))
        .join('\n');
    final match = RegExp(r'```json\n(.*?)\n```', dotAll: true).firstMatch(text);

    if (match == null) throw CatalogError.missingExample(catalog);

    final Object? json;
    try {
      json = jsonDecode(match[1] ?? '');
    } on FormatException catch (error) {
      throw CatalogError.invalidExample(catalog, problem: error.message);
    }

    if (json is! List<Object?> ||
        json.any((component) => component is! Map<String, Object?>)) {
      throw CatalogError.invalidExample(
        catalog,
        problem: 'write a JSON array of components',
      );
    }

    final guidelines = text
        .replaceRange(match.start, match.end, '')
        .trim()
        .replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return ._(guidelines, json.cast<Map<String, Object?>>());
  }
}

bool _isWidget(DartType type) =>
    type is InterfaceType &&
    (_widgetClass.isExactlyType(type) ||
        type.allSupertypes.any(_widgetClass.isExactlyType));

/// Whether [type] is or holds a widget, which the agent sets only as a child
/// of exactly `Widget` or `List<Widget>`.
bool _holdsWidget(DartType type) => switch (type) {
  InterfaceType(isDartCoreList: true, :final typeArguments) ||
  InterfaceType(
    isDartCoreSet: true,
    :final typeArguments,
  ) => _holdsWidget(typeArguments.single),
  _ => _isWidget(type),
};

const _widgetClass = TypeChecker.typeNamedLiterally(
  'Widget',
  inPackage: 'flutter',
);
