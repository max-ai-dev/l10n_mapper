import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:l10n_mapper_generator/l10n_mapper_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

class _BuildStepStub implements BuildStep {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('generates mapper output for AppLocalizations with analyzer 10', () async {
    final tempDir = await Directory.systemTemp.createTemp('l10n_mapper_generator_test_');

    try {
      final sourceFile = File('${tempDir.path}/lib/app_localizations.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
library app_localizations;

abstract class AppLocalizations {
  String get title;
  String greeting(String name);
  String balance(num amount, {required String currency});
}
''');

      final collection = AnalysisContextCollection(
        includedPaths: [tempDir.path],
        sdkPath: File(Platform.resolvedExecutable).parent.parent.path,
      );

      try {
        final context = collection.contextFor(sourceFile.path);
        final result = await context.currentSession.getResolvedLibrary(sourceFile.path);

        expect(result, isA<ResolvedLibraryResult>());

        final generated = await L10nMapperGenerator(
          l10n: true,
          locale: true,
          parseL10n: true,
          message: null,
          useNamedParameters: true,
        ).generate(LibraryReader((result as ResolvedLibraryResult).element), _BuildStepStub());

        expect(generated, isNotNull);
        expect(generated, contains('abstract class AppLocalizationsKey'));
        expect(generated, contains("'title' => title,"));
        expect(generated, contains("'greeting' => switch ((arguments, namedArguments)) {"));
        expect(generated, contains("'balance' => switch ((arguments, namedArguments)) {"));
        expect(
          generated,
          contains(
            'return localizations.parseL10n(translationKey, arguments: arguments, namedArguments: namedArguments);',
          ),
        );
      } finally {
        await collection.dispose();
      }
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
