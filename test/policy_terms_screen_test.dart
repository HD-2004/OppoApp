import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/policy_terms_screen.dart';
import 'package:oppo_temp_jobs/features/policies/application/policy_providers.dart';
import 'package:oppo_temp_jobs/features/policies/data/policy_repository.dart';

void main() {
  const source = '''
ỐP PỜ
Nền tảng tuyển dụng thời vụ F&B
TÀI LIỆU CHÍNH SÁCH NỀN TẢNG

Phiên bản 1.0  |  Cập nhật: 2026

CHÍNH SÁCH 01:
ĐIỀU KHOẢN SỬ DỤNG CHUNG
Áp dụng cho: Tất cả người dùng
Hiệu lực: Ngay khi đăng ký tài khoản

Nội dung điều khoản thật.

CHÍNH SÁCH 02:
BẢO MẬT & DỮ LIỆU CÁ NHÂN
Áp dụng cho: Tất cả người dùng

Nội dung bảo mật thật.
''';

  testWidgets('shows configured policies and opens exact detail content', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policyRepositoryProvider.overrideWithValue(
            const BundledPolicyRepository(source: source),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: PolicyTermsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ĐIỀU KHOẢN SỬ DỤNG CHUNG'), findsOneWidget);
    expect(find.text('BẢO MẬT & DỮ LIỆU CÁ NHÂN'), findsOneWidget);
    expect(find.textContaining('Tìm kiếm sẽ được'), findsNothing);

    await tester.tap(find.text('ĐIỀU KHOẢN SỬ DỤNG CHUNG'));
    await tester.pumpAndSettle();

    expect(find.text('Phiên bản 1.0'), findsOneWidget);
    expect(find.text('Hiệu lực: Ngay khi đăng ký tài khoản'), findsOneWidget);
    expect(
      find.textContaining('Nội dung điều khoản thật.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('shows empty state when no policy data is configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policyRepositoryProvider.overrideWithValue(
            const BundledPolicyRepository(source: ''),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: PolicyTermsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có chính sách được cấu hình'), findsOneWidget);
  });
}
