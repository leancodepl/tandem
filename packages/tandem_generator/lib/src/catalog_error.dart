import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

final class CatalogError extends InvalidGenerationSource {
  new notClass(Element element)
    : super(
        'Put @TandemCatalog([...]) on a class: ${element.displayName} is not '
        'one.',
        element: element,
      );

  new notWidget(Element catalog, {required DartType? type})
    : super(
        '@TandemCatalog lists widget classes, and '
        '${type?.getDisplayString() ?? 'one item'} is not one.',
        element: catalog,
      );

  new sameName(
    Element catalog, {
    required String name,
    required String first,
    required String second,
  }) : super(
         '${catalog.displayName} lists two widgets named $name, $first and '
         '$second. The agent names a component by its class: leave one out '
         'or rename it.',
         element: catalog,
       );

  new missingDocumentation(Element element)
    : super(
        'Add a doc comment to ${element.displayName}: the agent reads it to '
        'know what to draw with it.',
        element: element,
      );

  new missingExample(Element catalog)
    : super(
        'Add an example view to the doc comment of ${catalog.displayName}: a '
        '```json block with the components of a view for this screen.',
        element: catalog,
      );

  new invalidExample(Element catalog, {required String problem})
    : super(
        'The example of ${catalog.displayName}: $problem.',
        element: catalog,
      );

  new exampleComponent(
    Element catalog, {
    required String id,
    required String name,
    required Iterable<String> names,
  }) : super(
         'The example of ${catalog.displayName}: $id has no component $name. '
         'Components: ${names.join(', ')}.',
         element: catalog,
       );

  new exampleProperty(
    Element catalog, {
    required String id,
    required String component,
    required String property,
    required Iterable<String> properties,
  }) : super(
         'The example of ${catalog.displayName}: $id: $component has no '
         '"$property". Properties: ${properties.join(', ')}.',
         element: catalog,
       );

  new missingConstructor(Element widget)
    : super(
        'Tandem builds ${widget.displayName} with its unnamed constructor, '
        'and it has no public one.',
        element: widget,
      );

  new unnamedWidget(Element widget)
    : super(
        'Import the library of ${widget.displayName} where the catalog is, '
        'so that the generated code can build it.',
        element: widget,
      );

  new unnamedType(Element widget, {required FormalParameterElement parameter})
    : super(
        '${widget.displayName}.${parameter.displayName}: import '
        '${parameter.type.getDisplayString()} where the catalog is, or give '
        '${widget.displayName} a getter ${parameter.displayName} of that type, '
        'so that the generated code knows its type.',
        element: widget,
      );

  new childType(Element widget, {required FormalParameterElement parameter})
    : super(
        '${widget.displayName}.${parameter.displayName}: the agent sets a '
        'child as Widget or List<Widget>, and '
        '${parameter.type.getDisplayString()} is neither. Type it as one of '
        'them, or leave ${widget.displayName} out.',
        element: widget,
      );

  new skippedPositional(Element widget, {required String parameter})
    : super(
        '${widget.displayName}.$parameter is positional and the agent cannot '
        'set it, so the parameters after it cannot be set either. Make it '
        'named.',
        element: widget,
      );

  /// [converted] is the type without `?` that the converter converts.
  new noForm(
    Element widget, {
    required FormalParameterElement parameter,
    required DartType converted,
  }) : super(
         '${widget.displayName}.${parameter.displayName}: '
         '${parameter.type.getDisplayString()} has no form. Add a '
         'JsonConverter<${converted.getDisplayString()}, S> to converters:, '
         'or leave ${widget.displayName} out.',
         element: widget,
       );

  /// The one line of the build for an optional parameter without a form.
  static String noFormMessage(
    Element widget,
    FormalParameterElement parameter,
  ) =>
      '${widget.displayName}.${parameter.displayName}: '
      '${parameter.type.getDisplayString()} has no form, so it keeps its '
      'default. A JsonConverter in converters: lets the agent set it.';

  /// The one line of the build for an optional parameter that holds a widget
  /// of another type than `Widget`.
  static String childTypeMessage(
    Element widget,
    FormalParameterElement parameter,
  ) =>
      '${widget.displayName}.${parameter.displayName}: the agent sets a child '
      'as Widget or List<Widget>, and ${parameter.type.getDisplayString()} is '
      'neither, so it keeps its default.';
}
