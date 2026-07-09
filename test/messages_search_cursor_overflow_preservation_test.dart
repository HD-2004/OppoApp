import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/messaging/application/messaging_providers.dart';
import 'package:oppo_temp_jobs/features/messaging/domain/candidate_application.dart';
import 'package:oppo_temp_jobs/features/messaging/presentation/pages/messages_screen.dart';
import 'package:oppo_temp_jobs/features/messaging/presentation/widgets/conversation_tile.dart';

/// Property 2: Preservation - Giữ nguyên chức năng và hiển thị của `_SearchBar`.
///
/// Đây là các TEST BẢO TOÀN HÀNH VI (observation-first) cho bugfix
/// `messages-search-cursor-overflow`. Chúng quan sát và ghi lại hành vi hiện có
/// (KHÔNG thỏa bug condition) trên code CHƯA sửa và khẳng định baseline cần bảo
/// toàn sau khi sửa lỗi.
///
/// BẮT BUỘC: Tất cả test trong file này PHẢI PASS trên code CHƯA sửa
/// (xác nhận baseline). Sau khi áp dụng bản sửa, chúng vẫn phải PASS
/// (xác nhận không có hồi quy).
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
void main() {
  // ── Test data helpers ─────────────────────────────────────────────────────

  /// Một cuộc trò chuyện tối thiểu với tên công ty / chức danh kiểm soát được.
  /// Với danh sách job rỗng, `_resolveJob` sẽ suy ra companyName == employerName
  /// và jobTitle == jobTitle, nên việc lọc dựa trực tiếp trên hai trường này.
  CandidateApplication buildChat({
    required String id,
    required String employerName,
    required String jobTitle,
  }) {
    return CandidateApplication(
      applicationId: id,
      jobId: 'JOB-$id',
      jobTitle: jobTitle,
      jobType: 'standard',
      candidateId: 'cand',
      candidateEmail: 'cand@example.com',
      employerId: 'emp-$id',
      employerEmail: 'emp$id@example.com',
      employerName: employerName,
      status: 'accepted',
      appliedAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      chatMessages: const [],
    );
  }

  final sampleChats = <CandidateApplication>[
    buildChat(id: '1', employerName: 'Katinat Coffee', jobTitle: 'Pha chế'),
    buildChat(id: '2', employerName: 'Highlands', jobTitle: 'Phục vụ'),
    buildChat(id: '3', employerName: 'August Cafe', jobTitle: 'Thu ngân'),
  ];

  /// Mô phỏng CHÍNH XÁC logic lọc trong `MessagesScreen._buildList`:
  /// - Không lọc khi keyword sau khi trim là rỗng (hiển thị tất cả).
  /// - Ngược lại: companyName/jobTitle (lowercase) contains keyword (lowercase, KHÔNG trim).
  int expectedVisibleCount(List<CandidateApplication> chats, String keyword) {
    if (keyword.trim().isEmpty) return chats.length;
    final kw = keyword.toLowerCase();
    return chats
        .where(
          (c) =>
              c.employerName.toLowerCase().contains(kw) ||
              c.jobTitle.toLowerCase().contains(kw),
        )
        .length;
  }

  Future<void> pumpMessagesScreen(
    WidgetTester tester, {
    List<CandidateApplication> chats = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateChatsProvider.overrideWithBuild((_, _) => chats),
          activeJobsProvider.overrideWith((_) async => <JobPost>[]),
          activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
        ],
        child: const MaterialApp(home: MessagesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder searchField() => find.byType(TextField).first;

  // ── Req 3.1: gõ nội dung gọi onChanged và lọc danh sách ────────────────────

  testWidgets(
    'Req 3.1: gõ nội dung gọi onChanged với đúng giá trị và lọc danh sách '
    '(property-based, nhiều input ngẫu nhiên)',
    (tester) async {
      await pumpMessagesScreen(tester, chats: sampleChats);

      final random = Random(20240612);

      // Sinh keyword: phân nửa là substring có nghĩa trích từ dữ liệu,
      // phân nửa là chuỗi ngẫu nhiên — property phải đúng cho mọi input.
      final tokens = <String>[
        'Katinat',
        'coffee',
        'High',
        'phục',
        'PHA',
        'ngân',
        'August',
        'cafe',
      ];
      const randomChars = 'abcdefghijk lmnop XYZ 123 àáạ';

      String generateKeyword() {
        if (random.nextBool()) {
          return tokens[random.nextInt(tokens.length)];
        }
        final length = 1 + random.nextInt(8);
        final buffer = StringBuffer();
        for (var i = 0; i < length; i++) {
          buffer.write(randomChars[random.nextInt(randomChars.length)]);
        }
        return buffer.toString();
      }

      for (var i = 0; i < 30; i++) {
        final keyword = generateKeyword();
        await tester.enterText(searchField(), keyword);
        await tester.pumpAndSettle();

        // onChanged đã nhận đúng giá trị đã gõ (controller phản ánh giá trị).
        expect(
          tester.widget<TextField>(searchField()).controller?.text,
          keyword,
          reason: 'TextField phải giữ đúng giá trị "$keyword" đã gõ (Req 3.1).',
        );

        // onChanged đã được gọi và danh sách được lọc đúng như hiện tại.
        final expected = expectedVisibleCount(sampleChats, keyword);
        expect(
          find.byType(ConversationTile),
          findsNWidgets(expected),
          reason:
              'Với keyword "$keyword" danh sách phải lọc còn $expected mục '
              '(Req 3.1).',
        );
      }
    },
  );

  // ── Req 3.2: nút xóa hiển thị khi có nội dung và gọi onClear khi nhấn ──────

  testWidgets(
    'Req 3.2: nút xóa (close_rounded) hiển thị khi có nội dung và xóa khi nhấn',
    (tester) async {
      await pumpMessagesScreen(tester, chats: sampleChats);

      // Ban đầu rỗng: không có nút xóa.
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Khi có nội dung: nút xóa xuất hiện.
      await tester.enterText(searchField(), 'Katinat');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Nhấn nút xóa: gọi onClear -> xóa nội dung, nút xóa biến mất.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(searchField()).controller?.text, isEmpty);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      // Nội dung xóa -> bộ lọc trống -> hiển thị lại toàn bộ danh sách.
      expect(find.byType(ConversationTile), findsNWidgets(sampleChats.length));
    },
  );

  // ── Req 3.3: placeholder giữ nguyên fontSize 14 và màu disabledFor ────────

  testWidgets(
    'Req 3.3: placeholder "Tìm kiếm cuộc trò chuyện..." giữ fontSize 14 và màu '
    'AppColors.disabledFor',
    (tester) async {
      await pumpMessagesScreen(tester);

      final textField = tester.widget<TextField>(searchField());
      final hintStyle = textField.decoration?.hintText == null
          ? null
          : textField.decoration?.hintStyle;

      expect(
        textField.decoration?.hintText,
        'Tìm kiếm cuộc trò chuyện...',
        reason: 'Placeholder phải giữ nguyên (Req 3.3).',
      );
      expect(
        hintStyle?.fontSize,
        14,
        reason: 'Placeholder fontSize phải là 14.',
      );

      final ctx = tester.element(searchField());
      expect(
        hintStyle?.color,
        AppColors.disabledFor(ctx),
        reason: 'Màu placeholder phải là AppColors.disabledFor.',
      );
    },
  );

  // ── Req 3.4: nền fieldFill, bo góc 12, icon search_rounded, bố cục Row ─────

  testWidgets(
    'Req 3.4: nền AppColors.fieldFill, bo góc radius 12, icon search_rounded và '
    'bố cục Row giữ nguyên',
    (tester) async {
      await pumpMessagesScreen(tester);

      final ctx = tester.element(searchField());

      // Container khung ô tìm kiếm: nền fieldFill + bo góc 12.
      final containers = tester.widgetList<Container>(
        find.ancestor(of: searchField(), matching: find.byType(Container)),
      );
      final searchContainer = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == AppColors.fieldFill(ctx),
        orElse: () => throw StateError(
          'Không tìm thấy Container nền AppColors.fieldFill cho ô tìm kiếm.',
        ),
      );
      final decoration = searchContainer.decoration as BoxDecoration;
      expect(
        decoration.color,
        AppColors.fieldFill(ctx),
        reason: 'Màu nền khung phải là AppColors.fieldFill (Req 3.4).',
      );
      expect(
        decoration.borderRadius,
        BorderRadius.circular(12),
        reason: 'Bo góc khung phải là radius 12 (Req 3.4).',
      );

      // Icon tìm kiếm và bố cục Row giữ nguyên.
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(
        find.ancestor(of: searchField(), matching: find.byType(Row)),
        findsWidgets,
        reason: 'TextField phải nằm trong bố cục Row (Req 3.4).',
      );
    },
  );

  // ── Req 3.5: TextField ở màn hình khác không bị ảnh hưởng ─────────────────

  testWidgets(
    'Req 3.5: một TextField ở màn hình khác hiển thị và hoạt động bình thường',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Ô nhập khác'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'không bị ảnh hưởng');
      await tester.pumpAndSettle();

      expect(controller.text, 'không bị ảnh hưởng');
    },
  );
}
