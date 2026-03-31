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
  group('parseKey', () {
    test('First and second lookup work', () {
      final localizations = lookupAppLocalizations(const Locale('en'));

      final result1 =
          localizations.parseKey(AppLocalizationsKeys.cashierDeposit);
      expect(result1, isNotEmpty);

      final result2 =
          localizations.parseKey(AppLocalizationsKeys.cashierWithdraw);
      expect(result2, isNotEmpty);
    });

    test('Different locales return different results', () {
      final localizationsEn = lookupAppLocalizations(const Locale('en'));
      final localizationsDe = lookupAppLocalizations(const Locale('de'));

      final resultEn =
          localizationsEn.parseKey(AppLocalizationsKeys.cashierDeposit);
      expect(resultEn, isNotEmpty);

      final resultDe =
          localizationsDe.parseKey(AppLocalizationsKeys.cashierDeposit);
      expect(resultDe, isNotEmpty);

      expect(resultEn, isNot(equals(resultDe)));
    });

    test('Performance: Multiple lookups are fast', () {
      final localizations = lookupAppLocalizations(const Locale('en'));

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 1000; i++) {
        localizations.parseKey(AppLocalizationsKeys.localeName);
        localizations.parseKey(AppLocalizationsKeys.cashierActivateTronlink);
        localizations.parseKey(AppLocalizationsKeys.cashierActiveBalance);
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      debugPrint('3000 lookups took: ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Parameterized translations work', () {
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
  });

  group('lookup', () {
    test('returns String for getter keys', () {
      final localizations = lookupAppLocalizations(const Locale('en'));

      final result = localizations.lookup(AppLocalizationsKeys.cashierDeposit);

      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });

    test('returns String for parameterized keys', () {
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
  });

  group('Benchmark', () {
    test('Switch-based lookup performance', () {
      final localizations = lookupAppLocalizations(const Locale('en'));

      final stopwatch1 = Stopwatch()..start();
      localizations.parseKey(AppLocalizationsKeys.cashierDeposit);
      stopwatch1.stop();
      final firstLookupTime = stopwatch1.elapsedMicroseconds;

      final stopwatch2 = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        localizations.parseKey(AppLocalizationsKeys.cashierDeposit);
      }
      stopwatch2.stop();
      final subsequentLookupTime = stopwatch2.elapsedMicroseconds;

      debugPrint('First lookup: $firstLookupTimeμs');
      debugPrint('100 lookups: $subsequentLookupTimeμs');
      debugPrint('Average per lookup: ${subsequentLookupTime / 100}μs');

      expect(subsequentLookupTime, lessThan(10000)); // < 10ms for 100 lookups
    });
  });
}
