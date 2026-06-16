import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/features/wallet/presentation/widgets/wallet_quick_actions.dart';

void main() {
  testWidgets('wallet quick actions omit revenue statistics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WalletQuickActions(
            onWithdraw: () {},
            onHistory: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rút tiền'), findsOneWidget);
    expect(find.text('Lịch sử giao dịch'), findsOneWidget);
    expect(find.text('Thống kê thu nhập'), findsNothing);
  });
}
