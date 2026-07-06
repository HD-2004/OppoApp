# AWS Amplify + Cognito Setup

Mục tiêu của app là dùng Cognito User Pool đã có sẵn, không tạo User Pool mới.

User Pool hiện tại:

- Region: `ap-southeast-1`
- User Pool ID: `ap-southeast-1_ShCajkmJd`
- User Pool name: `OpPoWebUserPool`
- Cognito endpoint: `https://cognito-idp.ap-southeast-1.amazonaws.com/ap-southeast-1_ShCajkmJd`
- JWKS URL: `https://cognito-idp.ap-southeast-1.amazonaws.com/ap-southeast-1_ShCajkmJd/.well-known/jwks.json`

Audit ngày 24/05/2026:

- App Client tìm thấy: `OpPoWebClient`
- App Client ID: `2mv7qt4gpmq03dmlm0or9724n8`
- App Client thuộc đúng User Pool: `ap-southeast-1_ShCajkmJd`
- `ClientSecret` không xuất hiện trong `describe-user-pool-client`, phù hợp cho mobile app.
- Email auto verification đang bật: `AutoVerifiedAttributes = email`
- MFA: `OFF`
- Password policy: tối thiểu 8 ký tự, bắt buộc chữ hoa, chữ thường, số, ký tự đặc biệt.
- `custom:role` chưa tồn tại trong schema attributes.
- Cognito Groups hiện có: `Candidate`, `Employer`, `Admin`.

Kiến trúc auth:

- Cognito User Pool xác thực email/password và email OTP.
- Flutter dùng Amplify Auth để gọi `signUp`, `confirmSignUp`, `signIn`, `signOut`, `resetPassword`, `confirmResetPassword`, `fetchAuthSession`.
- Role được ưu tiên lưu trong Cognito custom attribute `custom:role`.
- Giá trị role app hợp lệ: `user`, `candidate`, `employer`.
- App lưu role Candidate bằng giá trị domain `user`; vẫn parse được Cognito Group `Candidate`.
- Vì User Pool hiện chưa có `custom:role`, app hiện fallback role bằng Cognito Groups.
- Khi sign up, app gửi `clientMetadata.role = candidate|employer` để Lambda trigger hiện có có thể add user vào group nếu backend đã hỗ trợ.
- Nếu Lambda chưa xử lý metadata role, dùng DynamoDB `Users` table làm fallback, với khóa `userId/sub` từ Cognito.

Không chạy `amplify init`, `amplify add auth`, hoặc Amplify sandbox để tạo auth mới cho project này.

## PHASE 1: Kiểm Tra User Pool Hiện Tại

Trong AWS Console:

1. Vào **Amazon Cognito**.
2. Chọn region **Asia Pacific (Singapore) ap-southeast-1**.
3. Mở **User pools**.
4. Kiểm tra User Pool ID phải đúng:

```text
ap-southeast-1_ShCajkmJd
```

Kiểm tra App Client ID:

1. Trong User Pool, mở tab **Applications** hoặc **App integration**.
2. Chọn **App clients**.
3. Mở app client dành cho mobile app.
4. Copy **Client ID**.
5. Đảm bảo app client **không có client secret**.

Nếu chưa có App Client phù hợp, tạo App Client mới trong chính User Pool này:

- Application type: public client hoặc mobile/native app.
- Không bật client secret.
- Auth flow nên hỗ trợ SRP/password sign-in.
- Không tạo User Pool mới.

Kiểm tra `custom:role`:

1. Trong User Pool, mở **Sign-up** hoặc **Attributes**.
2. Tìm custom attribute tên `role`.
3. Khi dùng trong code, Cognito sẽ đọc/ghi dưới dạng `custom:role`.
4. Nếu chưa có, chỉ thêm khi bạn chắc chắn pool cho phép và App Client có quyền ghi attribute này.

Kết quả audit hiện tại: `custom:role` chưa tồn tại. Không tự động thêm bằng CLI trong task này vì custom attribute sau khi tạo thường không sửa/xóa dễ dàng.

AWS CLI kiểm tra nhanh:

```powershell
aws cognito-idp describe-user-pool `
  --region ap-southeast-1 `
  --user-pool-id ap-southeast-1_ShCajkmJd

aws cognito-idp list-user-pool-clients `
  --region ap-southeast-1 `
  --user-pool-id ap-southeast-1_ShCajkmJd
```

Không dùng lệnh update/delete nếu chưa review kỹ.

## PHASE 2: Cấu Hình Amplify Flutter

Các package đã có trong `pubspec.yaml`:

- `amplify_flutter`
- `amplify_auth_cognito`

File cấu hình chính:

```text
lib/amplifyconfiguration.dart
```

File này đã trỏ tới:

```text
Region: ap-southeast-1
User Pool ID: ap-southeast-1_ShCajkmJd
```

App Client ID không hardcode trực tiếp. Khi chạy app, truyền bằng `--dart-define`:

```powershell
flutter run --dart-define=COGNITO_USER_POOL_CLIENT_ID=your_app_client_id
```

Nếu không truyền `--dart-define`, app dùng App Client ID đã audit được:

```text
2mv7qt4gpmq03dmlm0or9724n8
```

Mobile app tuyệt đối không dùng client secret.

## PHASE 3: Auth Service

Code đã được tách thành:

- `lib/features/auth/data/auth_service.dart`
- `lib/features/auth/data/auth_repository.dart`
- `lib/features/auth/application/auth_controller.dart`

Các hàm đã có:

- `configureAmplify()`
- `signUp()`
- `confirmSignUp()`
- `signIn()`
- `signOut()`
- `resetPassword()`
- `confirmResetPassword()`
- `getCurrentUser()`
- `fetchUserRole()`
- `checkAuthSession()`
- `fetchAuthSession()`
- `fetchUserAttributes()`
- `resendSignUpCode()`
- `routeAfterLogin()`

Lỗi được map trong `auth_service.dart`, gồm:

- email đã tồn tại
- sai password/email
- user chưa confirm email
- mã OTP sai hoặc hết hạn
- email không tồn tại khi quên mật khẩu
- gửi OTP quá nhiều lần
- lỗi network
- lỗi thiếu cấu hình Cognito
- lỗi thiếu `custom:role`

Mapper lỗi nằm ở:

```text
lib/core/errors/auth_exception_mapper.dart
```

## PHASE 4: Register Flow

Màn hình:

```text
lib/features/auth/presentation/register_screen.dart
```

Field:

- Full name
- Email
- Password
- Confirm password
- Role selector: Candidate hoặc Employer

Khi đăng ký, app gửi:

```text
email
name
clientMetadata.role = user hoặc employer
```

App chỉ gửi `custom:role` khi `useCognitoCustomRoleAttribute = true` trong `lib/core/config/amplify_config.dart`.

Sau khi đăng ký thành công, router chuyển sang màn nhập mã OTP.

## PHASE 5: Login Flow

Màn hình:

```text
lib/features/auth/presentation/login_screen.dart
```

Sau đăng nhập:

- `custom:role = user` hoặc `candidate` → `/candidate`
- `custom:role = employer` → `/employer`
- Cognito group `Candidate` → `/candidate`
- Cognito group `Employer` → `/employer`
- không có role → `/missing-role`

Candidate/User routing:

- `kycCompleted = false` → `/candidate/kyc`
- `kycCompleted = true` và `profileCompleted = false` → `/candidate/update-profile`
- `kycCompleted = true` và `profileCompleted = true` → `/candidate`

Employer routing:

- `employerStatus = pending_review` → `/employer/pending-review`
- `employerStatus = approved` → `/employer`
- `employerStatus = rejected` → `/employer/rejected`

Nếu role không có trong Cognito, phương án an toàn tiếp theo là tạo DynamoDB `Users` table:

```text
id/sub
email
fullName
role
createdAt
updatedAt
```

Sau đó `fetchUserRole()` sẽ query table bằng Cognito `sub`.

## PHASE 6: Forgot Password Flow

Màn hình:

```text
lib/features/auth/presentation/forgot_password_screen.dart
lib/features/auth/presentation/reset_password_screen.dart
```

Luồng:

1. Từ LoginScreen, chọn **Quên mật khẩu?**.
2. App chuyển đến `/forgot-password`.
3. Người dùng nhập email và bấm **Gửi mã xác nhận**.
4. Cognito gửi OTP/reset code về email nếu tài khoản hợp lệ.
5. App chuyển đến `/reset-password`.
6. Người dùng nhập email, OTP, mật khẩu mới, xác nhận mật khẩu mới.
7. Nếu thành công, app thông báo và chuyển về `/login`.

Flow này chỉ dùng Cognito User Pool hiện tại:

```text
ap-southeast-1_ShCajkmJd
```

Không tạo User Pool mới và không thay đổi cấu hình pool.

## PHASE 7: Role-Based Routing

Router nằm ở:

```text
lib/app/router.dart
```

Luồng điều hướng:

- unauthenticated → `/login`
- unconfirmed → `/confirm-signup`
- forgot password → `/forgot-password`
- reset password → `/reset-password`
- candidate → `/candidate`
- employer → `/employer`
- authenticated nhưng thiếu role → `/missing-role`

## PHASE 8: Cấu Trúc Thư Mục

Đề xuất hiện tại:

```text
lib/
  core/
    errors/
  features/
    auth/
      application/
      data/
      domain/
      presentation/
    candidate/
      presentation/
        kyc_verification_screen.dart
        update_profile_screen.dart
        user_dashboard_screen.dart
    employer/
      presentation/
        employer_home_screen.dart
        employer_pending_review_screen.dart
        employer_rejected_screen.dart
    urgent_jobs/
      application/
      data/
      domain/
      presentation/
  shared/
    domain/
```

## PHASE 9: Checklist

Trước khi test thật:

- User Pool ID đúng: `ap-southeast-1_ShCajkmJd`
- Region đúng: `ap-southeast-1`
- App Client ID lấy từ chính User Pool hiện tại
- App Client không có client secret
- App Client cho phép sign up/sign in phù hợp với email/password
- Email verification đang bật
- `custom:role` hiện chưa tồn tại; dùng Cognito Groups hoặc DynamoDB Users table fallback
- App Client có quyền sign up/sign in/forgot password
- Chạy app với `--dart-define=COGNITO_USER_POOL_CLIENT_ID=...` nếu muốn override App Client ID
- Log không báo `Amplify Auth skipped`
- Đăng ký gửi được `clientMetadata.role`
- Lambda/backend add được user vào group `Candidate` hoặc `Employer`, hoặc DynamoDB fallback lưu được role
- OTP confirm thành công
- Login redirect đúng role
- Candidate chưa KYC đi tới KYC Verification
- Candidate hoàn thành KYC đi tới Update Profile
- Candidate hoàn thành profile đi tới Dashboard User
- Employer pending_review đi tới màn chờ duyệt
- Employer approved đi tới Dashboard NTD
- Employer rejected đi tới màn bị từ chối
- Forgot password gửi được mã xác nhận
- Reset password đổi được mật khẩu mới
- Login lại được bằng mật khẩu mới

## PHASE 10: Google Hosted UI Cho Web/GitHub Pages

Để đăng nhập / đăng ký Google trên bản web giống website, Flutter Web phải dùng
đúng Cognito Hosted UI domain và redirect HTTPS của trang đang deploy.

GitHub Actions đã đọc các biến repo-level sau:

```text
COGNITO_HOSTED_UI_DOMAIN
COGNITO_USER_POOL_CLIENT_ID
```

Job deploy GitHub Pages chỉ chạy khi `COGNITO_HOSTED_UI_DOMAIN` đã được cấu
hình. Nếu biến này chưa có, workflow vẫn chạy analyze/test nhưng bỏ qua deploy
để không tạo bản web Google sign-in sai cấu hình.

Trong GitHub:

1. Vào **Settings** → **Secrets and variables** → **Actions**.
2. Mở tab **Variables**.
3. Tạo biến `COGNITO_HOSTED_UI_DOMAIN` với giá trị domain Hosted UI thật của
   website, chỉ nhập domain trần, ví dụ:

```text
your-domain.auth.ap-southeast-1.amazoncognito.com
```

4. Nếu cần override App Client, tạo thêm `COGNITO_USER_POOL_CLIENT_ID`. Nếu
   không tạo, app dùng App Client ID đã audit:

```text
2mv7qt4gpmq03dmlm0or9724n8
```

Trong Cognito App Client đang dùng cho Google Hosted UI, thêm các URL này vào
**Allowed callback URLs** và **Allowed sign-out URLs**:

```text
com.oppo.tempjobs://
https://hd-2004.github.io/OppoApp/
```

Nếu tên owner/repo GitHub khác, thay URL GitHub Pages theo dạng:

```text
https://<github-owner>.github.io/<repo-name>/
```

Local web có thể chạy thử bằng:

```powershell
flutter run -d chrome `
  --dart-define=COGNITO_HOSTED_UI_DOMAIN=your-domain.auth.ap-southeast-1.amazoncognito.com `
  --dart-define=COGNITO_WEB_REDIRECT_URI=http://localhost:PORT/
```

Android/iOS vẫn dùng redirect scheme:

```text
com.oppo.tempjobs://
```

Nguồn chính thức:

- Amplify Flutter dùng Cognito User Pool hiện có: https://docs.amplify.aws/flutter/build-a-backend/auth/use-existing-cognito-resources/
- Kết nối Flutter với resource hiện có: https://docs.amplify.aws/flutter/frontend/connect-to-existing-resources/
- Custom user attributes trong Amplify Flutter: https://docs.amplify.aws/flutter/frontend/auth/manage-user-attributes/
- Cognito app clients và client secret: https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-client-apps.html
