import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/application/notification_controller.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/user_dashboard_screen.dart';
import 'package:oppo_temp_jobs/features/wallet/domain/entities/revenue_statistics.dart';
import 'package:oppo_temp_jobs/features/wallet/domain/entities/wallet.dart';
import 'package:oppo_temp_jobs/features/wallet/presentation/controllers/wallet_controller.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';

void main() {
  testWidgets(
    'home does not show search bar while jobs tab still opens search page',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWithBuild(
              (_, _) => AuthState.authenticated(_candidateUser),
            ),
            candidateNotificationControllerProvider.overrideWithBuild(
              (_, _) => const CandidateNotificationList(
                items: [],
                summary: CandidateNotificationSummary(total: 0, unread: 0),
              ),
            ),
            walletControllerProvider.overrideWithBuild(
              (_, _) => const WalletState(
                wallet: WalletOverview(
                  availableBalance: 0,
                  pendingBalance: 0,
                  totalEarnings: 0,
                  currency: 'VND',
                  status: WalletStatus.active,
                ),
                recentTransactions: [],
                transactions: [],
                statistics: RevenueStatistics(
                  thisWeekIncome: 0,
                  thisMonthIncome: 0,
                  completedShifts: 0,
                  averageIncomePerShift: 0,
                ),
              ),
            ),
            activeJobsProvider.overrideWith((_) async => <JobPost>[]),
            activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
          ],
          child: const MaterialApp(
            locale: Locale('vi'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: UserDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tìm kiếm công việc F&B n...'), findsNothing);
      expect(find.text('Tìm kiếm'), findsNothing);
      expect(find.text('Công việc'), findsOneWidget);

      await tester.tap(find.text('Công việc'));
      await tester.pumpAndSettle();

      expect(find.text('Tìm kiếm ca làm, quán cafe...'), findsOneWidget);

      final homeNavLabel = tester.widget<Text>(find.text('Trang chủ'));
      expect(homeNavLabel.style?.color, const Color(0xFF6B7280));

      final searchNavLabel = tester.widget<Text>(find.text('Công việc'));
      expect(searchNavLabel.style?.color, AppColors.primary);
    },
  );
}

const _candidateUser = AuthUserProfile(
  userId: 'candidate-1',
  username: 'candidate',
  role: AppRole.candidate,
  email: 'candidate@example.com',
  fullName: 'Nguyen An',
  kycCompleted: true,
  profileCompleted: true,
);
