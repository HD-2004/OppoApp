import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/messaging/application/messaging_providers.dart';
import 'package:oppo_temp_jobs/features/messaging/domain/candidate_application.dart';
import 'package:oppo_temp_jobs/features/messaging/presentation/pages/messages_screen.dart';

/// Property 1: Bug Condition - Con trỏ nằm gọn và căn giữa trong khung ô tìm kiếm.
///
/// Đây là TEST KHÁM PHÁ ĐIỀU KIỆN LỖI (exploration test) cho bugfix
/// `messages-search-cursor-overflow`. Test mã hóa HÀNH VI MONG MUỐN (sau khi sửa):
///   - `TextField` của `_SearchBar` có `textAlignVertical: TextAlignVertical.center`
///   - `contentPadding` có padding dọc hợp lý (khác `EdgeInsets.zero`)
///   - Chiều cao con trỏ (caret) <= chiều cao khung ô tìm kiếm
///
/// BẮT BUỘC: Test này PHẢI FAIL trên code CHƯA sửa (khung cao 44,
/// thiếu `textAlignVertical`, `contentPadding: EdgeInsets.zero`).
/// Thất bại xác nhận lỗi tồn tại. KHÔNG sửa test/code khi nó fail ở bước này.
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 2.1, 2.2, 2.3**
void main() {
  // Dựng màn hình Tin nhắn (chứa `_SearchBar`) với các provider được override
  // để không gọi mạng. Đây là cách truy cập `_SearchBar` (private) qua widget
  // công khai `MessagesScreen`.
  Future<void> pumpMessagesScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateChatsProvider.overrideWithBuild(
            (_, _) => <CandidateApplication>[],
          ),
          activeJobsProvider.overrideWith((_) async => <JobPost>[]),
          activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
        ],
        child: const MaterialApp(home: MessagesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Đọc các thuộc tính render của ô tìm kiếm và kiểm chứng Property 1.
  void assertSearchBarCursorFitsAndCentered(WidgetTester tester) {
    final searchFieldFinder = find.widgetWithText(
      TextField,
      'Tìm kiếm cuộc trò chuyện...',
    );

    // Fallback: nếu hint không khớp (đang có nội dung), lấy TextField đầu tiên.
    final fieldFinder = searchFieldFinder.evaluate().isNotEmpty
        ? searchFieldFinder
        : find.byType(TextField).first;

    final textField = tester.widget<TextField>(fieldFinder);

    // (1) Con trỏ/chữ phải được căn giữa theo chiều dọc.
    expect(
      textField.textAlignVertical,
      TextAlignVertical.center,
      reason:
          'TextField của ô tìm kiếm phải dùng textAlignVertical.center để con '
          'trỏ được căn giữa và nằm gọn trong khung (Req 2.2, 2.3).',
    );

    // (2) contentPadding phải có padding dọc hợp lý (khác EdgeInsets.zero).
    final contentPadding = textField.decoration?.contentPadding;
    expect(
      contentPadding,
      isNot(EdgeInsets.zero),
      reason:
          'contentPadding: EdgeInsets.zero ép con trỏ sát mép vùng nhập liệu '
          'trong khung quá thấp, khiến con trỏ tràn ra ngoài (Req 2.1).',
    );
    final resolved = (contentPadding ?? EdgeInsets.zero).resolve(
      TextDirection.ltr,
    );
    expect(
      resolved.top + resolved.bottom,
      greaterThan(0),
      reason: 'Cần padding dọc > 0 để con trỏ ngồi cân đối trong khung.',
    );

    // (3) Chiều cao con trỏ (xấp xỉ preferredLineHeight) không vượt quá khung.
    final containerFinder = find.ancestor(
      of: fieldFinder,
      matching: find.byType(Container),
    );
    final containerSize = tester.getSize(containerFinder.first);

    // Lấy RenderEditable một cách an toàn qua EditableTextState. Ở phiên bản
    // Flutter này, render object gốc của EditableText là một
    // `_RenderCompositionCallback` (không phải RenderEditable), nên không thể
    // ép kiểu trực tiếp bằng renderObject<RenderEditable>. Truy cập state để
    // lấy đúng `renderEditable` và đọc `preferredLineHeight`.
    final editableState = tester.state<EditableTextState>(
      find.descendant(of: fieldFinder, matching: find.byType(EditableText)),
    );
    final caretHeight = editableState.renderEditable.preferredLineHeight;

    expect(
      caretHeight,
      lessThanOrEqualTo(containerSize.height),
      reason:
          'Chiều cao con trỏ ($caretHeight) phải <= chiều cao khung '
          '(${containerSize.height}) để con trỏ không tràn ra ngoài (Req 2.1, 2.3).',
    );
  }

  testWidgets(
    'Property 1: cursor nằm gọn & căn giữa trong khung ô tìm kiếm (empty + nhiều input)',
    (tester) async {
      // Scoped PBT: thu hẹp miền input về các trạng thái cụ thể của ô tìm kiếm
      // trên màn hình Tin nhắn khi focus: (a) rỗng chỉ có placeholder,
      // (b) đang có nội dung (sinh ngẫu nhiên nhiều chuỗi nhập).
      final random = Random(20240611);
      const sampleChars =
          'abcdefghijklmnopqrstuvwxyz ÀÁẠÃÂĐêôươ Nam Hà Nội 0123456789';

      String generateKeyword() {
        final length = 1 + random.nextInt(20);
        final buffer = StringBuffer();
        for (var i = 0; i < length; i++) {
          buffer.write(sampleChars[random.nextInt(sampleChars.length)]);
        }
        return buffer.toString();
      }

      // Trường hợp (a): ô rỗng, chỉ có placeholder, focus vào ô.
      await pumpMessagesScreen(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      assertSearchBarCursorFitsAndCentered(tester);

      // Trường hợp (b): sinh nhiều chuỗi nhập ngẫu nhiên và kiểm chứng property.
      for (var i = 0; i < 25; i++) {
        final keyword = generateKeyword();
        await tester.enterText(find.byType(TextField).first, keyword);
        await tester.pumpAndSettle();
        assertSearchBarCursorFitsAndCentered(tester);
      }
    },
  );
}
