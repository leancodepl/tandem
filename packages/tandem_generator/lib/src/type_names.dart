import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Names types in the code of a library, as its own declarations and its
/// imports, with their prefixes, make them visible.
final class TypeNames(final LibraryElement _library) {
  /// [type] as code of the library, or null when the library does not see
  /// it or a type inside it.
  String? name(DartType type) {
    if (type is! InterfaceType) return null;

    final base = _visibleName(type.element);

    if (base == null) return null;

    final arguments = <String>[];

    for (final argument in type.typeArguments) {
      final name = this.name(argument);

      if (name == null) return null;

      arguments.add(name);
    }

    final suffix = type.nullabilitySuffix == .none ? '' : '?';
    final list = arguments.isEmpty ? '' : '<${arguments.join(', ')}>';

    return '$base$list$suffix';
  }

  String? _visibleName(InterfaceElement element) {
    final name = element.displayName;

    if (element.library == _library) return name;

    for (final import in _library.firstFragment.libraryImports) {
      if (import.namespace.get2(name) != element) continue;

      return switch (import.prefix?.element.displayName) {
        final prefix? => '$prefix.$name',
        null => name,
      };
    }

    return null;
  }
}
