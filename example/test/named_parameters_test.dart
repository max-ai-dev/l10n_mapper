import 'package:example/localization/gen-l10n/app_localizations.dart';
import 'package:example/localization/gen-l10n/app_localizations.mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnknownKey extends AppLocalizationsKey {
  const _UnknownKey();

  @override
  String get rawKey => 'nonExistentKey';
}

void main() {
  group('named parameters', () {
    test('parseKey supports generated named factories', () {
      final localizations = lookupAppLocalizations(const Locale('en'));

      final result = localizations.parseKey(
        AppLocalizationsKeys.cashierMinimumDeposit(
          amount: 100,
          currency: 'USD',
        ),
      );

      expect(result, isNotEmpty);
      expect(result, contains('100'));
      expect(result, contains('USD'));
    });

    test('lookup supports generated named factories', () {
      final localizations = lookupAppLocalizations(const Locale('en'));

      final result = localizations.lookup(
        AppLocalizationsKeys.cashierMinimumDeposit(
          amount: 100,
          currency: 'USD',
        ),
      );

      expect(result, isA<String>());
      expect(result, contains('100'));
      expect(result, contains('USD'));
    });

    test('parseL10n still supports namedArguments for compatibility', () {
      final localizations = lookupAppLocalizations(const Locale('en'));

      final result = localizations.parseL10n(
        'cashierMinimumDeposit',
        namedArguments: {'amount': 100, 'currency': 'USD'},
      );

      expect(result, isNotEmpty);
      expect(result, contains('100'));
      expect(result, contains('USD'));
    });

    test('lookupKey still supports namedArguments for compatibility', () {
      final localizations = lookupAppLocalizations(const Locale('en'));

      final result = localizations.lookupKey(
        'cashierMinimumDeposit',
        namedArguments: {'amount': 100, 'currency': 'USD'},
      );

      expect(result, isA<String>());
      expect(result, contains('100'));
      expect(result, contains('USD'));
    });

    test('parseKey returns the fallback for unknown typed keys', () {
      final localizations = lookupAppLocalizations(const Locale('en'));

      final result = localizations.parseKey(const _UnknownKey());

      expect(result, equals('Translation key not found!'));
    });

    test('lookup returns null for unknown typed keys', () {
      final localizations = lookupAppLocalizations(const Locale('en'));

      final result = localizations.lookup(const _UnknownKey());

      expect(result, isNull);
    });
  });
}
