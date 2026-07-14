import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/employer/presentation/company_profile_screen.dart';

void main() {
  testWidgets('company profile does not render static highlight benefits', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeJobsProvider.overrideWith((_) async => const <JobPost>[]),
          activeQuickJobsProvider.overrideWith((_) async => const <JobPost>[]),
        ],
        child: const MaterialApp(
          home: CompanyProfileScreen(
            employerId: 'employer-1',
            companyName: 'Bamos',
            tags: ['F&B'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lương thưởng'), findsNothing);
    expect(find.text('Môi trường'), findsNothing);
    expect(find.text('Cơ hội học hỏi'), findsNothing);
    expect(
      find.text('Mức lương cạnh tranh so với thị trường, thanh toán đúng hạn.'),
      findsNothing,
    );
    expect(
      find.text('Đồng nghiệp trẻ trung, năng động, hỗ trợ nhau nhiệt tình.'),
      findsNothing,
    );
    expect(
      find.text('Được đào tạo và phát triển kỹ năng chuyên môn.'),
      findsNothing,
    );
    expect(find.text('Đánh giá từ nhân viên'), findsOneWidget);
  });

  testWidgets('helpful reviews tab shows five-star reviews sorted by hearts', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeJobsProvider.overrideWith((_) async => const <JobPost>[]),
          activeQuickJobsProvider.overrideWith((_) async => const <JobPost>[]),
        ],
        child: MaterialApp(
          home: CompanyProfileScreen(
            employerId: 'employer-1',
            companyName: 'Bamos',
            employeeReviews: [
              CompanyEmployeeReview(
                id: 'recent-4-star',
                authorName: 'Ứng viên mới',
                rating: 4,
                comment: 'Bốn sao không vào hữu ích.',
                heartCount: 99,
                createdAt: DateTime(2026, 7, 14),
              ),
              CompanyEmployeeReview(
                id: 'five-star-low-heart',
                authorName: 'Ứng viên 5 sao ít tim',
                rating: 5,
                comment: 'Năm sao ít tim.',
                heartCount: 3,
                createdAt: DateTime(2026, 7, 12),
              ),
              CompanyEmployeeReview(
                id: 'five-star-high-heart',
                authorName: 'Ứng viên 5 sao nhiều tim',
                rating: 5,
                comment: 'Năm sao nhiều tim.',
                heartCount: 12,
                createdAt: DateTime(2026, 7, 11),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bốn sao không vào hữu ích.'), findsOneWidget);

    await tester.tap(find.text('HỮU ÍCH'));
    await tester.pumpAndSettle();

    expect(find.text('Bốn sao không vào hữu ích.'), findsNothing);
    expect(find.text('Năm sao nhiều tim.'), findsOneWidget);
    expect(find.text('Năm sao ít tim.'), findsOneWidget);

    final highHeartTop = tester.getTopLeft(find.text('Năm sao nhiều tim.')).dy;
    final lowHeartTop = tester.getTopLeft(find.text('Năm sao ít tim.')).dy;
    expect(highHeartTop, lessThan(lowHeartTop));
  });
}
