import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/employer_packages/application/featured_employer_package_providers.dart';
import 'package:oppo_temp_jobs/features/employer_packages/domain/employer_package.dart';
import 'package:oppo_temp_jobs/features/employer_packages/presentation/widgets/featured_employer_banner.dart';
import 'package:oppo_temp_jobs/features/employer_packages/presentation/widgets/package_status_card.dart';

void main() {
  testWidgets(
    'featured employer banner shows empty state when backend has no data',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featuredEmployersProvider.overrideWith(
              (_) async => <FeaturedEmployer>[],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FeaturedEmployerBanner(onViewJobs: null)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hiện chưa có nhà tuyển dụng nổi bật'), findsOneWidget);
    },
  );

  testWidgets(
    'package status card shows empty state when employer has no package',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPackageStatusProvider.overrideWith((_) async => null),
          ],
          child: const MaterialApp(
            home: Scaffold(body: PackageStatusCard(onRenew: null)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa đăng ký gói hiển thị'), findsOneWidget);
    },
  );
}
