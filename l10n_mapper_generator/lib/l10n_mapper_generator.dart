import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

export 'l10n_mapper_builder.dart';

// indicates methods mapper would not be generated for
const genExceptions = ['of', 'delegate', 'localizationsDelegates', 'supportedLocales'];

String _typeDisplay(FormalParameterElement parameter) {
  return parameter.type.getDisplayString();
}

String _pascalCase(String value) {
  final parts = value.split(RegExp(r'[^A-Za-z0-9]+')).where((part) => part.isNotEmpty);
  return parts.map((part) => '${part[0].toUpperCase()}${part.substring(1)}').join();
}

String _typedKeyBaseClassName(String className) => '${className}Key';

String _typedKeyFactoryClassName(String className) => '${className}Keys';

String _privateKeyClassName(String className, String memberName) {
  return '_$className${_pascalCase(memberName)}Key';
}

String _generateListPattern(List<FormalParameterElement> parameters) {
  return parameters.map((parameter) => 'final ${_typeDisplay(parameter)} ${parameter.displayName}').join(', ');
}

String _generateNamedMapPattern(List<FormalParameterElement> parameters) {
  return parameters
      .map((parameter) => "'${parameter.displayName}': final ${_typeDisplay(parameter)} ${parameter.displayName}")
      .join(', ');
}

String _generateMethodInvocation(String methodName, List<FormalParameterElement> parameters) {
  final positionalArguments = <String>[];
  final namedArguments = <String>[];

  for (final parameter in parameters) {
    if (parameter.isNamed) {
      namedArguments.add('${parameter.displayName}: ${parameter.displayName}');
    } else {
      positionalArguments.add(parameter.displayName);
    }
  }

  final invocationArguments = [...positionalArguments, ...namedArguments];
  return '$methodName(${invocationArguments.join(', ')})';
}

String _generateMethodCase(MethodElement method, bool useNamedParameters) {
  final methodName = method.displayName;
  final parameters = method.formalParameters.toList();
  final positionalParameters = parameters.where((parameter) => !parameter.isNamed).toList();
  final namedParameters = parameters.where((parameter) => parameter.isNamed).toList();
  final invocation = _generateMethodInvocation(methodName, parameters);
  final buffer = StringBuffer();

  if (parameters.isEmpty) {
    buffer.writeln("      '$methodName' => $methodName(),");
    return buffer.toString();
  }

  if (namedParameters.isEmpty) {
    final positionalPattern = _generateListPattern(positionalParameters);

    if (useNamedParameters) {
      final namedPattern = _generateNamedMapPattern(positionalParameters);
      final parameterNames = positionalParameters.map((parameter) => parameter.displayName).join(', ');

      buffer.writeln('      \'$methodName\' => switch ((arguments, namedArguments)) {');
      buffer.writeln('        ([$positionalPattern], _) => $invocation,');
      buffer.writeln('        (_, {$namedPattern}) => $invocation,');
      buffer.writeln('        _ => throw ArgumentError(\'$methodName requires arguments: $parameterNames\'),');
      buffer.writeln('      },');
      return buffer.toString();
    }

    final positionalDescription =
        '${positionalParameters.length} positional argument${positionalParameters.length == 1 ? '' : 's'}';
    buffer.writeln('      \'$methodName\' => switch (arguments) {');
    buffer.writeln('        [$positionalPattern] => $invocation,');
    buffer.writeln('        _ => throw ArgumentError(\'$methodName requires $positionalDescription\'),');
    buffer.writeln('      },');
    return buffer.toString();
  }

  if (positionalParameters.isEmpty) {
    final namedPattern = _generateNamedMapPattern(namedParameters);
    final namedDescription = namedParameters.map((parameter) => parameter.displayName).join(', ');

    buffer.writeln('      \'$methodName\' => switch (namedArguments) {');
    buffer.writeln('        {$namedPattern} => $invocation,');
    buffer.writeln('        _ => throw ArgumentError(\'$methodName requires named arguments: $namedDescription\'),');
    buffer.writeln('      },');
    return buffer.toString();
  }

  final positionalPattern = _generateListPattern(positionalParameters);
  final requiredNamedPattern = _generateNamedMapPattern(namedParameters);
  final namedDescription = namedParameters.map((parameter) => parameter.displayName).join(', ');

  buffer.writeln('      \'$methodName\' => switch ((arguments, namedArguments)) {');
  buffer.writeln('        ([$positionalPattern], {$requiredNamedPattern}) => $invocation,');

  if (useNamedParameters) {
    final allNamedPattern = _generateNamedMapPattern([...positionalParameters, ...namedParameters]);
    buffer.writeln('        (_, {$allNamedPattern}) => $invocation,');
  }

  buffer.writeln(
    "        _ => throw ArgumentError('$methodName requires ${positionalParameters.length} positional argument${positionalParameters.length == 1 ? '' : 's'} and named arguments: $namedDescription'),",
  );
  buffer.writeln('      },');
  return buffer.toString();
}

String _generateLookupKeyMethod(ClassElement classElement, bool useNamedParameters) {
  final buffer = StringBuffer();
  buffer.writeln('  Object? lookupKey(String key, {List<Object>? arguments, Map<String, Object?>? namedArguments}) {');
  buffer.writeln('    return switch (key) {');

  for (final field in classElement.fields) {
    final name = field.displayName;
    if (genExceptions.contains(name)) continue;
    buffer.writeln("      '$name' => $name,");
  }

  for (final method in classElement.methods) {
    final name = method.displayName;
    if (genExceptions.contains(name)) continue;
    buffer.write(_generateMethodCase(method, useNamedParameters));
  }

  buffer.writeln('      _ => null,');
  buffer.writeln('    };');
  buffer.writeln('  }');
  return buffer.toString();
}

String _generateParseResultBody(String lookupExpression, bool nullable, String? message) {
  final buffer = StringBuffer();
  buffer.writeln('    final result = $lookupExpression;');
  buffer.writeln('    if (result == null) {');
  if (nullable) {
    buffer.writeln('      return null;');
  } else {
    buffer.writeln("      return '${message!.replaceAll("'", "\\'")}';");
  }
  buffer.writeln('    }');
  buffer.writeln('    return result as String;');
  return buffer.toString();
}

String _generateTypedKeyModel(String className, ClassElement classElement) {
  final buffer = StringBuffer();
  final baseClassName = _typedKeyBaseClassName(className);
  final factoryClassName = _typedKeyFactoryClassName(className);

  buffer.writeln('abstract class $baseClassName {');
  buffer.writeln('  const $baseClassName();');
  buffer.writeln('  String get rawKey;');
  buffer.writeln('  List<Object>? get arguments => null;');
  buffer.writeln('  Map<String, Object?>? get namedArguments => null;');
  buffer.writeln('}');
  buffer.writeln('');

  buffer.writeln('abstract final class $factoryClassName {');

  for (final field in classElement.fields) {
    final name = field.displayName;
    if (genExceptions.contains(name)) continue;
    final privateClassName = _privateKeyClassName(className, name);
    buffer.writeln('  static const $name = $privateClassName();');
  }

  for (final method in classElement.methods) {
    final name = method.displayName;
    if (genExceptions.contains(name)) continue;

    final parameters = method.formalParameters.toList();
    if (parameters.isEmpty) {
      final privateClassName = _privateKeyClassName(className, name);
      buffer.writeln('  static const $name = $privateClassName();');
      continue;
    }

    final factoryParameters = parameters
        .map((parameter) => 'required ${_typeDisplay(parameter)} ${parameter.displayName}')
        .join(', ');
    final constructorArguments = parameters
        .map((parameter) => '${parameter.displayName}: ${parameter.displayName}')
        .join(', ');
    final privateClassName = _privateKeyClassName(className, name);

    buffer.writeln('  static $baseClassName $name({$factoryParameters}) =>');
    buffer.writeln('      $privateClassName($constructorArguments);');
  }

  buffer.writeln('}');
  buffer.writeln('');

  for (final field in classElement.fields) {
    final name = field.displayName;
    if (genExceptions.contains(name)) continue;
    final privateClassName = _privateKeyClassName(className, name);

    buffer.writeln('final class $privateClassName extends $baseClassName {');
    buffer.writeln('  const $privateClassName();');
    buffer.writeln("  @override String get rawKey => '$name';");
    buffer.writeln('}');
    buffer.writeln('');
  }

  for (final method in classElement.methods) {
    final name = method.displayName;
    if (genExceptions.contains(name)) continue;
    final parameters = method.formalParameters.toList();
    final privateClassName = _privateKeyClassName(className, name);

    if (parameters.isEmpty) {
      buffer.writeln('final class $privateClassName extends $baseClassName {');
      buffer.writeln('  const $privateClassName();');
      buffer.writeln("  @override String get rawKey => '$name';");
      buffer.writeln('}');
      buffer.writeln('');
      continue;
    }

    final positionalParameters = parameters.where((parameter) => !parameter.isNamed).toList();
    final namedParameters = parameters.where((parameter) => parameter.isNamed).toList();

    buffer.writeln('final class $privateClassName extends $baseClassName {');
    buffer.writeln(
      '  const $privateClassName({${parameters.map((parameter) => 'required this.${parameter.displayName}').join(', ')}});',
    );

    for (final parameter in parameters) {
      buffer.writeln('  final ${_typeDisplay(parameter)} ${parameter.displayName};');
    }

    buffer.writeln("  @override String get rawKey => '$name';");

    if (positionalParameters.isNotEmpty) {
      buffer.writeln(
        '  @override List<Object> get arguments => [${positionalParameters.map((parameter) => parameter.displayName).join(', ')}];',
      );
    }

    if (namedParameters.isNotEmpty) {
      buffer.writeln(
        "  @override Map<String, Object?> get namedArguments => {${namedParameters.map((parameter) => "'${parameter.displayName}': ${parameter.displayName}").join(', ')}};",
      );
    }

    buffer.writeln('}');
    buffer.writeln('');
  }

  return buffer.toString();
}

class L10nMapperGenerator extends Generator {
  final bool l10n;
  final bool locale;
  final bool parseL10n;
  List<String> classNames;

  //? optional and default: null. should be parsed if translation should not return
  //? nullable values when key is not found but will return specified error message instead
  final String? message;
  final bool useNamedParameters;

  L10nMapperGenerator({
    required this.l10n,
    required this.locale,
    required this.parseL10n,
    required this.message,
    required this.useNamedParameters,
    this.classNames = const [],
  });

  @override
  FutureOr<String?> generate(LibraryReader library, BuildStep buildStep) {
    final targetClassNames = classNames.isEmpty ? const ['AppLocalizations'] : classNames;

    final buffer = StringBuffer();

    for (final classElement in library.classes.where((candidate) => candidate.isAbstract)) {
      if (!targetClassNames.contains(classElement.displayName)) {
        continue;
      }

      final className = classElement.displayName;
      final localizationPath = classElement.library.uri;
      final appLocalizationsExtensionName = '${className}Extension';
      final buildContextExtensionName = 'BuildContextExtension';
      final typedKeyBaseClassName = _typedKeyBaseClassName(className);

      final nullable = message == null;
      final shouldGenerateExtensions = l10n || locale || parseL10n;

      buffer.writeln("import '$localizationPath';");
      buffer.writeln("import 'package:flutter/widgets.dart';");
      buffer.write(_generateTypedKeyModel(className, classElement));

      if (shouldGenerateExtensions) {
        final bufferBuildContextExtension = StringBuffer();
        final bufferAppLocalizationsExtension = StringBuffer();

        bufferBuildContextExtension.writeln('extension $buildContextExtensionName on BuildContext {');
        bufferAppLocalizationsExtension.writeln('extension $appLocalizationsExtensionName on $className {');

        bufferBuildContextExtension.writeln('  $className get _localizations => $className.of(this)!;');

        if (l10n) {
          bufferBuildContextExtension.writeln('  $className get l10n => _localizations;');
        }

        if (locale) {
          bufferBuildContextExtension.writeln('  Locale get locale => Localizations.localeOf(this);');
        }

        if (parseL10n) {
          bufferBuildContextExtension.writeln('  Object? lookup($typedKeyBaseClassName key) {');
          bufferBuildContextExtension.writeln('    final localizations = $className.of(this)!;');
          bufferBuildContextExtension.writeln('    return localizations.lookup(key);');
          bufferBuildContextExtension.writeln('  }');

          bufferBuildContextExtension.writeln(
            "  ${nullable ? 'String?' : 'String'} parseKey($typedKeyBaseClassName key) {",
          );
          bufferBuildContextExtension.writeln('    final localizations = $className.of(this)!;');
          bufferBuildContextExtension.writeln('    return localizations.parseKey(key);');
          bufferBuildContextExtension.writeln('  }');

          bufferBuildContextExtension.writeln(
            "  ${nullable ? 'String?' : 'String'} parseL10n(String translationKey, {List<Object>? arguments, Map<String, Object?>? namedArguments}) {",
          );
          bufferBuildContextExtension.writeln('    final localizations = $className.of(this)!;');
          bufferBuildContextExtension.writeln(
            '    return localizations.parseL10n(translationKey, arguments: arguments, namedArguments: namedArguments);',
          );
          bufferBuildContextExtension.writeln('  }');

          bufferAppLocalizationsExtension.write(_generateLookupKeyMethod(classElement, useNamedParameters));
          bufferAppLocalizationsExtension.writeln('  Object? lookup($typedKeyBaseClassName key) {');
          bufferAppLocalizationsExtension.writeln(
            '    return lookupKey(key.rawKey, arguments: key.arguments, namedArguments: key.namedArguments);',
          );
          bufferAppLocalizationsExtension.writeln('  }');

          bufferAppLocalizationsExtension.writeln(
            "  ${nullable ? 'String?' : 'String'} parseKey($typedKeyBaseClassName key) {",
          );
          bufferAppLocalizationsExtension.write(_generateParseResultBody('lookup(key)', nullable, message));
          bufferAppLocalizationsExtension.writeln('  }');

          bufferAppLocalizationsExtension.writeln(
            "  ${nullable ? 'String?' : 'String'} parseL10n(String translationKey, {List<Object>? arguments, Map<String, Object?>? namedArguments}) {",
          );
          bufferAppLocalizationsExtension.write(
            _generateParseResultBody(
              'lookupKey(translationKey, arguments: arguments, namedArguments: namedArguments)',
              nullable,
              message,
            ),
          );
          bufferAppLocalizationsExtension.writeln('  }');
        }

        bufferBuildContextExtension.writeln('}');
        bufferAppLocalizationsExtension.writeln('}');

        buffer
          ..write(bufferBuildContextExtension.toString())
          ..write(bufferAppLocalizationsExtension.toString());
      }

      return buffer.toString();
    }

    return super.generate(library, buildStep);
  }
}
