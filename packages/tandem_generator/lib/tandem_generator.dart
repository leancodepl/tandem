/// The build_runner builder behind `@TandemAgent()` and `@TandemCatalog()`
/// of `package:tandem`.
/// Apps add this package as a dev dependency and run
/// `dart run build_runner build`.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tandem_generator/src/agent_generator.dart';
import 'package:tandem_generator/src/catalog_generator.dart';

/// The builder of `_$Name` mixins of agents and catalogs, combined into the
/// library's `.g.dart`.
Builder tandemBuilder(BuilderOptions options) => SharedPartBuilder([
  const AgentGenerator(),
  const CatalogGenerator(),
], 'tandem');
