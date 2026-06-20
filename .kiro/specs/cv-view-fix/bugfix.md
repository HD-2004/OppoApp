# Bugfix Requirements Document

## Introduction

Người dùng không thể đọc/mở CV của ứng viên sau khi tải lên. Trong màn hình hồ sơ ứng viên
(`user_profile_screen.dart`, mục "CV / Hồ Sơ"), mỗi CV đã tải lên chỉ hiển thị biểu tượng file,
tên file (`cvFileName`), ngày tải lên (`cvUploadDate`) và nút Xóa. Không có bất kỳ hành động chạm/mở/xem
nào trên dòng CV, nên một CV đã tải lên không thể mở ra để đọc.

Trong khi đó, dữ liệu CV trả về từ backend đã chứa đường dẫn thực (`cvUrl`, và có thể `cvS3Key`)
được lưu trên S3. Việc sửa lỗi phải dựa hoàn toàn vào URL/khóa thực này từ backend — **tuyệt đối không
tạo dữ liệu giả hay mock data**. Ứng dụng hiện chưa có cơ chế nào để mở/hiển thị file CV
(không có `url_launcher`, WebView, hay package xem PDF trong `pubspec.yaml`), nên đây là nguyên nhân
gốc khiến CV không thể đọc được.

Phạm vi chính của lỗi là danh sách CV trong hồ sơ của chính ứng viên. Việc xem CV ở phía nhà tuyển dụng
(employer xem CV ứng viên) là tình huống liên quan, được ghi nhận nếu áp dụng nhưng không phải trọng tâm.

## Bug Analysis

### Current Behavior (Defect)

Hiện tại, khi một CV đã được tải lên thành công và hiển thị trong danh sách, không có cách nào để mở
và đọc nội dung CV đó.

1.1 WHEN người dùng chạm vào một dòng CV đã tải lên trong mục "CV / Hồ Sơ" THEN hệ thống không phản hồi và không mở được CV để đọc
1.2 WHEN một CV đã tải lên được hiển thị trong danh sách (có `cvUrl`/`cvS3Key` hợp lệ từ backend) THEN hệ thống không cung cấp bất kỳ hành động xem/mở/tải nào (chỉ có hành động Xóa)
1.3 WHEN người dùng muốn đọc nội dung CV (PDF, DOC, DOCX) THEN hệ thống không có cơ chế mở file vì ứng dụng chưa có thành phần hiển thị/khởi chạy file

### Expected Behavior (Correct)

Người dùng phải mở và đọc được CV đã tải lên, sử dụng đường dẫn thực từ backend.

2.1 WHEN người dùng chạm vào một dòng CV đã tải lên trong mục "CV / Hồ Sơ" THEN hệ thống SHALL mở CV đó để xem bằng cách dùng `cvUrl`/`cvS3Key` thực từ backend
2.2 WHEN một CV đã tải lên được hiển thị trong danh sách (có `cvUrl`/`cvS3Key` hợp lệ từ backend) THEN hệ thống SHALL hiển thị một hành động xem/mở rõ ràng trên dòng CV bên cạnh hành động Xóa
2.3 WHEN người dùng mở một CV với định dạng được hỗ trợ (PDF, DOC, DOCX) THEN hệ thống SHALL hiển thị hoặc khởi chạy file dựa trên đường dẫn thực mà không tạo dữ liệu giả
2.4 WHEN không thể mở CV (URL không hợp lệ, lỗi mạng, hoặc không có ứng dụng xem phù hợp) THEN hệ thống SHALL hiển thị thông báo lỗi rõ ràng cho người dùng thay vì im lặng không phản hồi

### Unchanged Behavior (Regression Prevention)

Các hành vi hiện có không liên quan đến lỗi phải được giữ nguyên.

3.1 WHEN người dùng tải một CV mới lên THEN hệ thống SHALL CONTINUE TO tải lên và làm mới danh sách CV như hiện tại
3.2 WHEN người dùng xóa một CV THEN hệ thống SHALL CONTINUE TO yêu cầu xác nhận và xóa CV như hiện tại
3.3 WHEN danh sách CV được tải THEN hệ thống SHALL CONTINUE TO hiển thị tên file và ngày tải lên như hiện tại
3.4 WHEN người dùng chưa tải CV nào hoặc đạt giới hạn số CV THEN hệ thống SHALL CONTINUE TO hiển thị các trạng thái/thông báo hiện có (còn lại bao nhiêu CV, giới hạn tối đa)
3.5 WHEN một CV được dùng để ứng tuyển công việc THEN hệ thống SHALL CONTINUE TO gửi `cvUrl`/`cvFilename` thực như hiện tại

## Bug Condition (C(X))

Sử dụng phương pháp bug-condition để xác định chính xác đầu vào gây lỗi và hành vi mong muốn.

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type CvItem   // một mục CV trong danh sách, có cvUrl/cvS3Key, cvFileName
  OUTPUT: boolean

  // CV đã tải lên hợp lệ (có đường dẫn thực từ backend) nhưng người dùng
  // không có cách nào mở để đọc -> đây là đầu vào gây lỗi.
  RETURN hasValidSource(X)        // X.cvUrl khác rỗng HOẶC X.cvS3Key khác rỗng
         AND userRequestsToView(X) // người dùng muốn mở/đọc CV
END FUNCTION
```

```pascal
// Property: Fix Checking - CV phải mở được để đọc
FOR ALL X WHERE isBugCondition(X) DO
  result ← openCv'(X)            // hành vi sau khi sửa
  ASSERT opens_viewer_or_launches(result)        // mở được trình xem/khởi chạy file
         AND uses_real_source(result, X.cvUrl OR X.cvS3Key)  // dùng đường dẫn thực, không mock
         AND (on_failure => shows_error_message(result))     // thất bại thì báo lỗi rõ ràng
END FOR
```

```pascal
// Property: Preservation Checking - giữ nguyên hành vi cho đầu vào không gây lỗi
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT uploadCv'(X)  = uploadCv(X)
     AND deleteCv'(X)  = deleteCv(X)
     AND renderList'(X) = renderList(X)
     AND submitApplication'(X) = submitApplication(X)
END FOR
```

**Định nghĩa:**
- **F**: Mã nguồn trước khi sửa — danh sách CV chỉ hiển thị thông tin và nút Xóa, không có hành động mở/xem.
- **F'**: Mã nguồn sau khi sửa — danh sách CV có hành động mở/xem dùng `cvUrl`/`cvS3Key` thực từ backend.
- **Counterexample**: Một CV đã tải lên có `cvUrl` hợp lệ; người dùng chạm vào dòng CV nhưng không có gì xảy ra (không mở được để đọc).
