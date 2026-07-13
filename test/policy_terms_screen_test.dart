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

  testWidgets('spaces policy detail lines with one blank line between items', (
    tester,
  ) async {
    const spacedSource = '''
ỐP PỜ

CHÍNH SÁCH 01:
ĐIỀU KHOẢN SỬ DỤNG CHUNG

Dòng thứ nhất.
Dòng thứ hai.

Dòng thứ ba.
''';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policyRepositoryProvider.overrideWithValue(
            const BundledPolicyRepository(source: spacedSource),
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

    await tester.tap(find.text('ĐIỀU KHOẢN SỬ DỤNG CHUNG'));
    await tester.pumpAndSettle();

    final detail = tester.widget<SelectableText>(find.byType(SelectableText));
    final detailText = detail.textSpan?.toPlainText() ?? detail.data;
    expect(
      detailText,
      contains('Dòng thứ nhất.\n\nDòng thứ hai.\n\nDòng thứ ba.'),
    );
    expect(detailText, isNot(contains('Dòng thứ nhất.\nDòng thứ hai.')));
  });

  testWidgets('collapses process table rows into compact mobile list', (
    tester,
  ) async {
    const tableSource = '''
ỐP PỜ

CHÍNH SÁCH 01:
VI PHẠM & XỬ LÝ TÀI KHOẢN

2. Quy trình xử lý vi phạm
Bước
Hành động
Thời gian xử lý
1
Tiếp nhận báo cáo/Hệ thống phát hiện vi phạm
Ngay lập tức
2
Xem xét bằng chứng và xác minh thông tin từ các bên liên quan
Trong 24 giờ làm việc
''';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policyRepositoryProvider.overrideWithValue(
            const BundledPolicyRepository(source: tableSource),
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

    await tester.tap(find.text('VI PHẠM & XỬ LÝ TÀI KHOẢN'));
    await tester.pumpAndSettle();

    final detail = tester.widget<SelectableText>(find.byType(SelectableText));
    final detailText = detail.textSpan?.toPlainText() ?? detail.data;

    expect(
      detailText,
      contains(
        '1. Tiếp nhận báo cáo/Hệ thống phát hiện vi phạm - Ngay lập tức',
      ),
    );
    expect(
      detailText,
      contains(
        '1. Tiếp nhận báo cáo/Hệ thống phát hiện vi phạm - Ngay lập tức\n'
        '2. Xem xét bằng chứng và xác minh thông tin từ các bên liên quan - Trong 24 giờ làm việc',
      ),
    );
    expect(detailText, isNot(contains('Bước\n\nHành động')));
    expect(detailText, isNot(contains('\n\nTiếp nhận báo cáo')));
  });

  testWidgets('renders policy headings and numbered items in bold', (
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

    await tester.tap(find.text('ĐIỀU KHOẢN SỬ DỤNG CHUNG'));
    await tester.pumpAndSettle();

    final detail = tester.widget<SelectableText>(find.byType(SelectableText));
    final spans = detail.textSpan!.children!.whereType<TextSpan>().toList();

    final policyHeader = spans.firstWhere(
      (span) => span.text == 'CHÍNH SÁCH 01:',
    );
    final title = spans.firstWhere(
      (span) => span.text == 'ĐIỀU KHOẢN SỬ DỤNG CHUNG',
    );
    final appliesTo = spans.firstWhere(
      (span) => span.text == 'Áp dụng cho: Tất cả người dùng',
    );

    expect(policyHeader.style?.fontWeight, FontWeight.w800);
    expect(title.style?.fontWeight, FontWeight.w800);
    expect(appliesTo.style?.fontWeight, FontWeight.w800);
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
