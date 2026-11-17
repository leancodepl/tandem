import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

/// Generates a mixin for each declaration carrying Tandem's [annotation].
abstract class const MixinGenerator(final String annotation) extends Generator {
  Future<String> generateMixin(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  );

  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    final checker = TypeChecker.typeNamedLiterally(
      annotation,
      inPackage: 'tandem',
    );
    final mixins = [
      for (final item in library.annotatedWith(checker))
        await generateMixin(item.element, item.annotation, buildStep),
    ];
    return mixins.isEmpty ? null : mixins.join('\n\n');
  }
}
