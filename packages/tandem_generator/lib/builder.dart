import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tandem_generator/src/agent_generator.dart';

/// The builder of `_$Name` mixins, combined into the library's `.g.dart`.
Builder tandemBuilder(BuilderOptions options) =>
    SharedPartBuilder([const AgentGenerator()], 'tandem');
