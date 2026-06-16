import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:oppo_temp_jobs/core/theme/app_theme.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/application/notification_controller.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/user_dashboard_screen.dart';
import 'package:oppo_temp_jobs/features/employer_packages/application/featured_employer_package_providers.dart';
import 'package:oppo_temp_jobs/features/employer_packages/domain/employer_package.dart';
import 'package:oppo_temp_jobs/features/messaging/application/messaging_providers.dart';
import 'package:oppo_temp_jobs/features/messaging/domain/candidate_application.dart';
import 'package:oppo_temp_jobs/features/recommendations/application/job_recommendation_providers.dart';
import 'package:oppo_temp_jobs/features/recommendations/domain/job_recommendation.dart';
import 'package:oppo_temp_jobs/features/wallet/domain/entities/wallet.dart';
import 'package:oppo_temp_jobs/features/wallet/presentation/controllers/wallet_controller.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';

void main() {
  testWidgets('jobs tab opens the web-aligned candidate jobs screen', (
    tester,
  ) async {
    await _pumpDashboard(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tìm kiếm công việc F&B n...'), findsNothing);
    expect(find.text('Tìm kiếm'), findsNothing);
    expect(find.text('Công việc'), findsOneWidget);

    await tester.tap(find.text('Công việc'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tìm công việc mơ ước của bạn'), findsOneWidget);
    expect(find.text('Công việc tiêu chuẩn'), findsOneWidget);
    expect(find.text('Công việc Tuyển gấp'), findsOneWidget);
    expect(find.text('Công việc đã lưu'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    final homeNavLabel = tester.widget<Text>(find.text('Trang chủ'));
    expect(homeNavLabel.style?.color, AppColors.textSecondary);

    final searchNavLabel = tester.widget<Text>(find.text('Công việc'));
    expect(searchNavLabel.style?.color, AppColors.primary);
  });

  testWidgets('drawer jobs item selects the bottom jobs tab', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDashboard(tester);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('Mở menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    await tester.tap(find.widgetWithText(ListTile, 'Công việc'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Tìm công việc mơ ước của bạn'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    final homeNavLabel = tester.widget<Text>(find.text('Trang chủ'));
    expect(homeNavLabel.style?.color, AppColors.textSecondary);

    final jobsNavLabel = tester.widget<Text>(find.text('Công việc'));
    expect(jobsNavLabel.style?.color, AppColors.primary);
  });
}

Future<void> _pumpDashboard(WidgetTester tester) async {
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
          ),
        ),
        activeJobsProvider.overrideWith((_) async => <JobPost>[]),
        activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
        personalizedJobRecommendationsProvider.overrideWith(
          (_) async => <JobRecommendation>[],
        ),
        featuredEmployersProvider.overrideWith(
          (_) async => <FeaturedEmployer>[],
        ),
        candidateChatsProvider.overrideWithBuild(
          (_, _) => <CandidateApplication>[],
        ),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.lightTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const UserDashboardScreen(),
      ),
    ),
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
