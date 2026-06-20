# Thiết kế Sửa lỗi: Con trỏ ô tìm kiếm tràn ra ngoài khung (messages-search-cursor-overflow)

## Overview

Ô tìm kiếm trên màn hình Tin nhắn (`_SearchBar` trong `lib/features/messaging/presentation/pages/messages_screen.dart`) hiển thị con trỏ nhập liệu (caret) cao hơn chiều cao của khung bo tròn 44px. Khi `TextField` được focus, con trỏ tràn ra ngoài giới hạn trên/dưới của `Container`, gây cảm giác lỗi giao diện.

Nguyên nhân nằm ở việc khung ô tìm kiếm **quá thấp** so với nội dung: `TextField` được đặt trong một `Container` có chiều cao cố định chỉ `height: 44`, kết hợp `isDense: true` + `contentPadding: EdgeInsets.zero` và **không** có cơ chế căn giữa theo chiều dọc (`textAlignVertical`). Với khung quá thấp, Flutter vẽ con trỏ (caret) theo chiều cao dòng mặc định của text mà vùng khung không đủ chỗ chứa, dẫn đến con trỏ/chữ tràn ra ngoài giới hạn trên/dưới của khung bo tròn, khiến giao diện trông như bị lỗi.

Chiến lược sửa lỗi là **tối thiểu và khu trú**: **phóng to (tăng chiều cao) khung ô tìm kiếm** trong `_SearchBar` để con trỏ và chữ có đủ không gian nằm gọn bên trong khung, đồng thời căn giữa theo chiều dọc, mà không thay đổi bất kỳ logic chức năng nào (gõ, lọc, xóa, placeholder, màu nền, bo góc, icon, bố cục) và không động đến các `TextField` ở màn hình khác.

## Glossary

- **Bug_Condition (C)**: Điều kiện kích hoạt lỗi — ô tìm kiếm màn hình Tin nhắn đang focus và con trỏ được vẽ cao hơn chiều cao khung (`caretHeight > containerHeight`) do khung quá thấp.
- **Property (P)**: Hành vi mong muốn — sau khi phóng to khung, con trỏ có chiều cao không vượt quá khung và được căn giữa theo chiều dọc, chữ và con trỏ nằm gọn thoải mái trong khung.
- **Preservation**: Các hành vi hiện có phải giữ nguyên — chức năng tìm kiếm (gõ/lọc/xóa), placeholder, màu nền/bo góc/icon, và các `TextField` ở màn hình khác.
- **`_SearchBar`**: Widget `StatelessWidget` trong `messages_screen.dart` dựng khung ô tìm kiếm gồm `Container` cao 44px chứa một `Row` với icon tìm kiếm, `TextField` (`Expanded`) và nút xóa.
- **`TextField`**: Trường nhập liệu bên trong `_SearchBar` hiện đang cấu hình `isDense: true`, `contentPadding: EdgeInsets.zero`, `fontSize: 14`, không có `textAlignVertical`.
- **Caret / cursor**: Con trỏ nhập liệu nhấp nháy mà Flutter vẽ trong `TextField`.

## Bug Details

### Bug Condition

Lỗi xảy ra khi ô tìm kiếm trên màn hình Tin nhắn được focus. `TextField` được đặt trong `Container` cao cố định **chỉ 44px** — quá thấp so với chiều cao dòng của text (`fontSize: 14`) cộng phần đệm — đồng thời dùng `isDense: true` + `contentPadding: EdgeInsets.zero` mà thiếu `textAlignVertical: TextAlignVertical.center`. Vì khung không đủ chỗ, Flutter vẽ con trỏ/chữ với chiều cao vượt quá vùng hiển thị gọn trong khung và căn theo mép trên thay vì giữa, khiến con trỏ tràn ra ngoài giới hạn trên/dưới của khung bo tròn.

**Formal Specification:**
```
FUNCTION isBugCondition(X)
  INPUT: X mô tả trạng thái hiển thị của ô tìm kiếm trên màn hình Tin nhắn
  OUTPUT: boolean

  RETURN X.isMessagesSearchBar = true
         AND X.isFocused = true
         AND caretHeight(X) > containerHeight(X)
END FUNCTION
```

### Examples

- **Focus rỗng**: Người dùng chạm vào ô tìm kiếm khi chưa gõ gì (chỉ có placeholder). Mong đợi: con trỏ nằm gọn, căn giữa. Thực tế: con trỏ tràn lên/xuống ngoài khung 44px.
- **Đang gõ**: Người dùng gõ "Nam". Mong đợi: con trỏ căn giữa theo chiều dọc, chiều cao ≤ chiều cao khung. Thực tế: con trỏ cao hơn khung, không căn giữa.
- **Edge case — màn hình khác**: Một `TextField` trên màn hình khác (ví dụ form đăng nhập) được focus. Đây KHÔNG phải bug condition và phải hiển thị y như cũ.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Gõ nội dung vào ô tìm kiếm vẫn gọi callback `onChanged` và lọc danh sách cuộc trò chuyện như hiện tại (Req 3.1).
- Nút xóa (icon `close_rounded`) vẫn hiển thị khi có nội dung và xóa nội dung khi nhấn (Req 3.2).
- Placeholder "Tìm kiếm cuộc trò chuyện..." giữ nguyên kiểu chữ, kích thước (`fontSize: 14`) và màu (`AppColors.disabledFor`) (Req 3.3).
- Kích thước khung được phóng to có chủ đích (44 → ~48–52); màu nền (`AppColors.fieldFill`), bo góc (radius 12), icon tìm kiếm và bố cục `Row` tổng thể giữ nguyên (Req 3.4).
- Mọi `TextField`/ô tìm kiếm ở các màn hình khác không bị ảnh hưởng (Req 3.5).

**Scope:**
Tất cả input KHÔNG thỏa bug condition phải hoàn toàn không bị ảnh hưởng bởi bản sửa lỗi này, bao gồm:
- Tương tác chức năng với ô tìm kiếm (gõ, lọc, xóa nội dung).
- Hiển thị placeholder, icon, nền và bố cục khung.
- Mọi `TextField` ở các widget/màn hình khác trong ứng dụng.

_Lưu ý: Hành vi đúng mong muốn cho con trỏ được định nghĩa trong mục Correctness Properties (Property 1)._

## Hypothesized Root Cause

Dựa trên phân tích mã nguồn thực tế của `_SearchBar` và phản hồi của người dùng (giao diện trông bị lỗi vì ô tìm kiếm quá thấp), các nguyên nhân khả dĩ là:

1. **Khung ô tìm kiếm quá thấp**: `Container` cha cố định `height: 44` không đủ chỗ cho chiều cao dòng của text (`fontSize: 14`) cộng phần đệm và con trỏ, nên con trỏ/chữ bị tràn ra ngoài giới hạn trên/dưới của khung. Đây là nguyên nhân chính được nghi ngờ.

2. **Thiếu căn giữa theo chiều dọc**: `TextField` không khai báo `textAlignVertical`, nên với `contentPadding: EdgeInsets.zero` nội dung và con trỏ bị căn theo mép trên của vùng nhập liệu thay vì giữa khung, làm lộ rõ phần tràn.

3. **`contentPadding: EdgeInsets.zero` quá chật**: Padding bằng 0 khiến text và con trỏ ép sát mép vùng nhập liệu trong khung vốn đã thấp, càng làm con trỏ tràn ra ngoài.

Giả thuyết ưu tiên: kết hợp (1) và (2) — **phóng to chiều cao khung** lên khoảng 48–52px để con trỏ và chữ có đủ không gian, đồng thời thêm căn giữa theo chiều dọc (`textAlignVertical: TextAlignVertical.center`) để con trỏ nằm gọn và căn giữa trong khung mới.

## Correctness Properties

Property 1: Bug Condition - Con trỏ nằm gọn và căn giữa trong khung

_For any_ trạng thái mà bug condition đúng (`isBugCondition` trả về true — ô tìm kiếm màn hình Tin nhắn đang focus), `_SearchBar` sau khi sửa (với khung được phóng to) SHALL hiển thị con trỏ có chiều cao không vượt quá chiều cao khung mới và được căn giữa theo chiều dọc trong khung, sao cho con trỏ và chữ nằm gọn thoải mái bên trong khung bo tròn, dù ô đang rỗng (placeholder) hay đang có nội dung.

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Preservation - Giữ nguyên chức năng và hiển thị cho các trường hợp khác

_For any_ trạng thái mà bug condition KHÔNG đúng (`isBugCondition` trả về false — gõ/lọc/xóa, placeholder, styling khung, hoặc bất kỳ `TextField` nào ở màn hình khác), `_SearchBar`/ứng dụng sau khi sửa SHALL cho kết quả giống hệt phiên bản trước khi sửa, bảo toàn toàn bộ chức năng và hiển thị hiện có.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

## Fix Implementation

### Changes Required

Giả định phân tích nguyên nhân ở trên là đúng, thay đổi chỉ giới hạn trong widget `_SearchBar`. Cách tiếp cận chính theo phản hồi người dùng là **phóng to khung ô tìm kiếm** để con trỏ và chữ vừa vặn thoải mái.

**File**: `lib/features/messaging/presentation/pages/messages_screen.dart`

**Function**: `_SearchBar.build` — phần `Container` bọc ngoài và `TextField` bên trong `Expanded`.

**Specific Changes**:
1. **Phóng to chiều cao khung**: Tăng `height` của `Container` từ `44` lên giá trị lớn hơn (khuyến nghị `48`–`52`) để con trỏ (caret) và chữ có đủ không gian nằm gọn trong khung bo tròn, không tràn ra ngoài giới hạn trên/dưới.

2. **Căn giữa theo chiều dọc**: Thêm (hoặc giữ) `textAlignVertical: TextAlignVertical.center` cho `TextField` để con trỏ và chữ được căn giữa theo chiều dọc trong khung đã phóng to.

3. **Điều chỉnh `contentPadding` hợp lý**: Thay `contentPadding: EdgeInsets.zero` bằng một giá trị padding dọc hợp lý (ví dụ `EdgeInsets.symmetric(vertical: 8)` hoặc tương đương) để chữ và con trỏ ngồi cân đối trong khung cao hơn, thay vì ép sát mép.

4. **Không đổi gì khác**: Giữ nguyên `controller`, `onChanged`, `decoration` (hintText "Tìm kiếm cuộc trò chuyện...", hintStyle, `border: InputBorder.none`, icon tìm kiếm), `style`, màu nền (`AppColors.fieldFill`), bo góc (radius 12), bố cục `Row` và nút xóa (`close_rounded` + `onClear`).

5. **Không ảnh hưởng màn hình khác**: Mọi thay đổi nằm trong `_SearchBar` của `messages_screen.dart`; không sửa theme/`InputDecorationTheme` toàn cục nên các `TextField` ở màn hình khác không bị ảnh hưởng.

Cách triển khai tối thiểu được khuyến nghị: tăng `height` của `Container` (44 → ~48–52), thêm `textAlignVertical: TextAlignVertical.center`, và đặt `contentPadding` dọc hợp lý. Đây là thay đổi nhỏ, an toàn, khu trú trong một widget.

## Testing Strategy

### Validation Approach

Quy trình hai pha: trước tiên dựng test/kiểm chứng phơi bày lỗi trên mã CHƯA sửa (con trỏ cao hơn / không căn giữa khung), sau đó xác nhận bản sửa làm con trỏ nằm gọn và căn giữa, đồng thời không phá vỡ hành vi hiện có. Vì đây là lỗi hiển thị UI, việc kiểm chứng kết hợp widget test (đo thuộc tính render của con trỏ qua `EditableText`/`RenderEditable`) và kiểm tra trực quan thủ công.

### Exploratory Bug Condition Checking

**Goal**: Phơi bày counterexample chứng minh lỗi TRƯỚC khi sửa và xác nhận/bác bỏ giả thuyết nguyên nhân. Nếu bác bỏ, cần đặt lại giả thuyết.

**Test Plan**: Dựng `_SearchBar` trong widget test, focus vào `TextField`, lấy widget `EditableText` và đọc các thuộc tính liên quan (`textAlignVertical`, `contentPadding`) cùng chiều cao khung hiện tại (44px). So sánh chiều cao con trỏ thực tế với chiều cao khung để quan sát lỗi. Bổ sung kiểm tra trực quan trên thiết bị/emulator.

**Test Cases**:
1. **Focus rỗng (placeholder)**: Focus vào ô khi chưa gõ; quan sát con trỏ tràn / không căn giữa (fail trên mã chưa sửa).
2. **Đang gõ**: Gõ một chuỗi rồi quan sát chiều cao và vị trí con trỏ (fail trên mã chưa sửa).
3. **Kiểm tra thuộc tính**: Khẳng định khung chỉ cao 44px, `EditableText` chưa có `textAlignVertical: center` và `contentPadding` bằng 0 (xác nhận root cause).

**Expected Counterexamples**:
- Con trỏ được vẽ với chiều cao vượt quá khung 44px và/hoặc căn theo mép trên.
- Nguyên nhân khả dĩ: khung quá thấp (44px), thiếu `textAlignVertical`, `contentPadding: EdgeInsets.zero` quá chật.

### Fix Checking

**Goal**: Xác nhận với mọi input thỏa bug condition, `_SearchBar` sau khi sửa cho hành vi đúng (con trỏ ≤ chiều cao khung và căn giữa).

**Pseudocode:**
```
FOR ALL X WHERE isBugCondition(X) DO
  result := renderSearchBar_fixed(X)
  ASSERT caretHeight(result) <= containerHeight(result)
         AND caretIsVerticallyCentered(result)
END FOR
```

### Preservation Checking

**Goal**: Xác nhận với mọi input KHÔNG thỏa bug condition, bản sửa cho kết quả giống hệt bản gốc.

**Pseudocode:**
```
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT renderSearchBar_original(X) = renderSearchBar_fixed(X)
END FOR
```

**Testing Approach**: Property-based testing phù hợp cho preservation checking vì sinh nhiều case tự động trên miền input (nhiều chuỗi nhập, trạng thái rỗng/không rỗng), bắt được edge case mà unit test thủ công dễ bỏ sót, và bảo đảm hành vi không đổi cho mọi input không-lỗi. Trước tiên quan sát hành vi trên mã CHƯA sửa, rồi viết property test ghi lại hành vi đó.

**Test Cases**:
1. **Bảo toàn gõ/lọc**: Quan sát `onChanged` được gọi và danh sách lọc đúng trên mã chưa sửa; viết test khẳng định điều này không đổi sau khi sửa.
2. **Bảo toàn nút xóa**: Quan sát nút xóa hiện khi có nội dung và xóa được nội dung; khẳng định không đổi sau khi sửa.
3. **Bảo toàn placeholder & styling**: Quan sát placeholder, màu nền, bo góc, icon; khẳng định không đổi sau khi sửa (lưu ý: chiều cao khung được phóng to có chủ đích).

### Unit Tests

- Kiểm tra `Container` của `_SearchBar` có `height` đã được phóng to (~48–52, lớn hơn 44).
- Kiểm tra `TextField` của `_SearchBar` có `textAlignVertical: TextAlignVertical.center` và `contentPadding` dọc hợp lý.
- Kiểm tra chiều cao con trỏ ≤ chiều cao khung mới khi focus (rỗng và có nội dung).
- Kiểm tra gõ nội dung gọi `onChanged`; nhấn nút xóa gọi `onClear`.

### Property-Based Tests

- Sinh nhiều chuỗi nhập ngẫu nhiên, khẳng định `onChanged` luôn nhận đúng giá trị và con trỏ luôn nằm gọn/căn giữa (Fix + Preservation hành vi chức năng).
- Sinh trạng thái rỗng/không rỗng ngẫu nhiên, khẳng định sự xuất hiện của nút xóa và hiển thị placeholder không đổi so với hành vi gốc.

### Integration Tests

- Mở màn hình Tin nhắn, focus ô tìm kiếm, gõ và xóa từ khóa; kiểm tra danh sách cuộc trò chuyện lọc đúng và giao diện ô tìm kiếm hiển thị chỉn chu (con trỏ không tràn).
- Kiểm tra một màn hình khác có `TextField` vẫn hiển thị và hoạt động như cũ (Req 3.5).
- Kiểm tra trực quan trên thiết bị/emulator: con trỏ căn giữa, nằm gọn trong khung bo tròn.
