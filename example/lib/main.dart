import 'package:example/localization/gen-l10n/app_localizations.dart';
import 'package:example/localization/gen-l10n/app_localizations.mapper.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      onGenerateTitle: (context) => context.l10n.cashierAccountsDesc,
      theme: ThemeData(primarySwatch: Colors.blue),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.parseKey(AppLocalizationsKeys.localeName)),
            const SizedBox(height: 20),
            Text(
              context.parseKey(
                AppLocalizationsKeys.ecPop_message(errorCode: '404'),
              ),
            ),
            const SizedBox(height: 20),
            Text(context.parseKey(AppLocalizationsKeys.cashierAccountsDesc)),
            const SizedBox(height: 20),
            Text(
              context.parseKey(
                AppLocalizationsKeys.cashierConvertBeforeWithdraw(
                  convertFrom: 'BTC',
                  convertTo: 'USD',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.parseKey(
                AppLocalizationsKeys.cashierConvertTo(currency: 'EUR'),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.parseKey(
                AppLocalizationsKeys.transactionExchangeWithdrawal(
                  from: 'BTC',
                  to: 'USD',
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }
}
