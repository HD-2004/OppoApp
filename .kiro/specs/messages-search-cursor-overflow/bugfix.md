# Tài liệu Yêu cầu Sửa lỗi

## Introduction

Ô tìm kiếm trên màn hình Tin nhắn (placeholder "Tìm kiếm cuộc trò chuyện...") đang hiển thị con trỏ nhập liệu (caret) cao hơn chiều cao của ô tìm kiếm. Khi người dùng chạm vào ô tìm kiếm để nhập nội dung, con trỏ nhấp nháy vượt ra ngoài giới hạn trên/dưới của khung bo tròn, gây cảm giác lỗi hiển thị và thiếu chỉn chu về mặt giao diện.

Phạm vi của bản sửa lỗi này chỉ giới hạn ở thanh tìm kiếm trên màn hình Tin nhắn (`_SearchBar` trong `lib/features/messaging/presentation/pages/messages_screen.dart`). Lỗi không ảnh hưởng đến chức năng tìm kiếm (gõ, lọc, xóa), chỉ liên quan đến cách hiển thị con trỏ trong ô.

## Bug Analysis

### Current Behavior (Defect)

Hành vi sai hiện tại khi tương tác với ô tìm kiếm trên màn hình Tin nhắn.

1.1 WHEN người dùng chạm (focus) vào ô tìm kiếm trên màn hình Tin nhắn THEN con trỏ nhập liệu (caret) hiển thị cao hơn chiều cao của khung ô tìm kiếm và tràn ra ngoài giới hạn trên/dưới của khung bo tròn

1.2 WHEN ô tìm kiếm đang được focus và chưa có nội dung (chỉ hiển thị placeholder) THEN con trỏ vẫn tràn ra ngoài khung ô tìm kiếm

1.3 WHEN người dùng đang gõ nội dung trong ô tìm kiếm THEN con trỏ không được căn giữa theo chiều dọc trong khung ô và vượt quá chiều cao của khung

### Expected Behavior (Correct)

Hành vi đúng mà ô tìm kiếm cần thể hiện.

2.1 WHEN người dùng chạm (focus) vào ô tìm kiếm trên màn hình Tin nhắn THEN the system SHALL hiển thị con trỏ nhập liệu nằm hoàn toàn bên trong chiều cao của khung ô tìm kiếm, không tràn ra ngoài giới hạn trên/dưới

2.2 WHEN ô tìm kiếm đang được focus và chưa có nội dung (chỉ hiển thị placeholder) THEN the system SHALL hiển thị con trỏ nằm gọn trong khung và được căn giữa theo chiều dọc của khung ô tìm kiếm

2.3 WHEN người dùng đang gõ nội dung trong ô tìm kiếm THEN the system SHALL hiển thị con trỏ được căn giữa theo chiều dọc và có chiều cao không vượt quá chiều cao của khung ô tìm kiếm

### Unchanged Behavior (Regression Prevention)

Các hành vi hiện có phải được giữ nguyên sau khi sửa lỗi.

3.1 WHEN người dùng gõ nội dung vào ô tìm kiếm THEN the system SHALL CONTINUE TO gọi callback tìm kiếm (onChanged) và lọc danh sách cuộc trò chuyện như hiện tại

3.2 WHEN ô tìm kiếm có nội dung THEN the system SHALL CONTINUE TO hiển thị nút xóa (biểu tượng close) và xóa nội dung khi người dùng nhấn vào

3.3 WHEN ô tìm kiếm chưa có nội dung THEN the system SHALL CONTINUE TO hiển thị placeholder "Tìm kiếm cuộc trò chuyện..." với kiểu chữ và màu sắc như hiện tại

3.4 WHEN ô tìm kiếm được hiển thị THEN the system SHALL CONTINUE TO giữ nguyên kích thước, màu nền, bo góc, biểu tượng tìm kiếm và bố cục tổng thể của khung như hiện tại

3.5 WHEN các ô tìm kiếm hoặc TextField ở các màn hình khác trong ứng dụng được hiển thị THEN the system SHALL CONTINUE TO hoạt động và hiển thị như hiện tại, không bị ảnh hưởng bởi bản sửa lỗi này

## Bug Condition (Điều kiện lỗi)

```pascal
FUNCTION isBugCondition(X)
  INPUT: X mô tả trạng thái hiển thị của ô tìm kiếm trên màn hình Tin nhắn
  OUTPUT: boolean

  // Lỗi xảy ra khi ô tìm kiếm trên màn hình Tin nhắn được focus
  // và con trỏ được vẽ với chiều cao vượt quá chiều cao khung ô
  RETURN X.isMessagesSearchBar = true
         AND X.isFocused = true
         AND caretHeight(X) > containerHeight(X)
END FUNCTION
```

## Property Specification

```pascal
// Property: Fix Checking - Con trỏ nằm gọn trong khung
FOR ALL X WHERE isBugCondition(X) DO
  result ← renderSearchBar'(X)
  ASSERT caretHeight(result) <= containerHeight(result)
         AND caretIsVerticallyCentered(result)
END FOR
```

```pascal
// Property: Preservation Checking - Giữ nguyên hành vi cho các trường hợp khác
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT renderSearchBar(X) = renderSearchBar'(X)
END FOR
```

**Định nghĩa:**
- **F (`renderSearchBar`)**: Cách hiển thị ô tìm kiếm trước khi sửa.
- **F' (`renderSearchBar'`)**: Cách hiển thị ô tìm kiếm sau khi sửa.
- **C(X)**: Ô tìm kiếm trên màn hình Tin nhắn đang focus và con trỏ cao hơn khung.
- **P(result)**: Con trỏ có chiều cao không vượt quá khung và được căn giữa theo chiều dọc.
