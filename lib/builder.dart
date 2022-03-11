/// Support for doing something awesome.
///
/// More dartdocs go here.
library rdf_vocab_gen.builder;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/generator.dart';

// TODO: Export any libraries intended for clients of this package.

Builder vocabLibraryBuilder(BuilderOptions options) => SharedPartBuilder(
      [VocabClassGenerator()],
      'vocab',
      // generatedExtension: '.vocab.dart',
    );
