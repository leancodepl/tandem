import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Names types in the code of a library, as its own declarations and its
/// imports, with their prefixes, make them visible.
final class TypeNames(final LibraryElement _library) {
  /// [type] as code of the library, or null when the library does not see
  /// it or a type inside it.
  String? name(DartType type) {
    if (type is! InterfaceType) return null;

    final base = visibleName(type.element);

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

  /// The name of [element] in the code of the library, without type
  /// arguments, or null when the library does not see it.
  String? visibleName(InterfaceElement element) {
    final name = element.displayName;

    if (element.library == _library) return name;

    for (final import in _library.firstFragment.libraryImports) {
      final visibleName = switch (import.prefix?.element.displayName) {
        final prefix? => '$prefix.$name',
        null => name,
      };

      if (import.namespace.get2(visibleName) == element) return visibleName;
    }

    return null;
  }
}
