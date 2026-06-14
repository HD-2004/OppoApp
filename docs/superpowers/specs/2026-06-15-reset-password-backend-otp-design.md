# Backend OTP Reset Password Design

## Goal

Replace the current Cognito-only forgot password flow with a real backend OTP flow. The mobile app must verify the OTP first, then navigate to a separate new-password step. No mock data, fake database, or in-memory OTP storage is allowed for production behavior.

## Current State

Flutter currently calls Amplify Auth directly:

- `resetPassword(email)` asks Cognito to send a reset code.
- `confirmResetPassword(email, confirmationCode, newPassword)` verifies the code and changes the password in one call.

This does not support a true standalone "verify OTP first, set password later" step.

The repo also has a FastAPI backend, but its current production repository boundaries are incomplete for auth reset. The backend uses `boto3`, so it can be extended to call DynamoDB, SES, and Cognito admin APIs.

## Chosen Approach

Build a custom backend reset-password flow:

1. Backend generates and sends the OTP.
2. Backend verifies OTP independently.
3. Backend returns a short-lived reset token only after OTP verification.
4. Backend changes the Cognito password using the reset token.
5. Flutter splits the reset password UI into OTP verification and new password screens/steps.

This replaces the mobile reset-password usage of Cognito's managed reset code for this flow.

## Backend API

### `POST /auth/password-reset/request`

Request:

```json
{
  "email": "user@example.com"
}
```

Behavior:

- Normalize email.
- Generate a 6-digit numeric OTP.
- Store only an OTP hash in DynamoDB, never the plain OTP.
- Store expiry, attempt count, and request metadata.
- Send OTP by SES email.
- Return a generic success response, even if the email is not found, to avoid account enumeration.

Response:

```json
{
  "success": true
}
```

### `POST /auth/password-reset/verify`

Request:

```json
{
  "email": "user@example.com",
  "otp": "123456"
}
```

Behavior:

- Find the active OTP challenge for the normalized email.
- Reject expired or over-attempted challenges.
- Compare the provided OTP with the stored hash.
- Increment failed attempts on mismatch.
- Mark the challenge as verified on success.
- Create a short-lived reset token and store only its hash.

Response:

```json
{
  "resetToken": "short-lived-token"
}
```

### `POST /auth/password-reset/confirm`

Request:

```json
{
  "email": "user@example.com",
  "resetToken": "short-lived-token",
  "newPassword": "NewPassword123!"
}
```

Behavior:

- Validate the reset token hash, expiry, and unused state.
- Validate the new password against the app/Cognito password policy.
- Reject reuse only if the backend can safely compare against password history. Because Cognito does not expose the old password, this design does not fake old-password comparison for unauthenticated reset.
- Call Cognito AdminSetUserPassword with `Permanent=True`.
- Mark the reset token/challenge as consumed.
- Return success.

Response:

```json
{
  "success": true
}
```

## Storage

Use a real DynamoDB table for reset challenges, for example `OppoPasswordResetChallenges`.

Suggested keys:

- Partition key: `email`
- Sort key: `challengeId`

Fields:

- `email`
- `challengeId`
- `otpHash`
- `resetTokenHash`
- `status`: `pending`, `verified`, `consumed`
- `attempts`
- `createdAt`
- `expiresAt`
- `verifiedAt`
- `consumedAt`

Enable DynamoDB TTL on `expiresAt`.

## Security Rules

- Do not store plain OTP or plain reset token.
- OTP length: 6 digits.
- OTP expiry: 10 minutes.
- Reset token expiry: 10 minutes after successful OTP verification.
- Max OTP attempts: 5.
- Request endpoint returns generic success to avoid leaking registered emails.
- Confirm endpoint consumes the token exactly once.
- Backend must require AWS config values for Cognito User Pool ID, SES sender, and DynamoDB table name. Missing production config should fail fast.

## Flutter Flow

### Forgot Password Screen

- Continue collecting email.
- Submit calls backend `request`.
- Navigate to reset password screen with email.

### Reset Password Screen

Split into two UI states:

1. OTP step
   - Shows email chip/input.
   - Shows OTP input only.
   - Button: `Xác thực OTP`.
   - On success, save `resetToken` in widget state only and switch/navigate to the new-password step.

2. New password step
   - Shows new password and confirm password fields.
   - Uses the existing password strength UI.
   - Calls backend `confirm` with `email`, `resetToken`, and `newPassword`.
   - On success, navigate to login.

No reset token is persisted to disk.

## Error Handling

Map backend errors to user-facing Vietnamese messages:

- Invalid/expired OTP: `Mã OTP không đúng hoặc đã hết hạn.`
- Too many attempts: `Bạn đã nhập sai OTP quá nhiều lần. Vui lòng gửi mã mới.`
- Expired reset session: `Phiên đổi mật khẩu đã hết hạn. Vui lòng xác thực OTP lại.`
- Weak password: reuse existing weak-password message.
- Unknown/network error: reuse existing unknown error handling.

## Testing

Backend tests:

- Request endpoint stores hashed OTP and returns generic success.
- Verify endpoint rejects wrong OTP and increments attempts.
- Verify endpoint returns reset token for a valid OTP.
- Confirm endpoint rejects invalid/expired/used token.
- Confirm endpoint calls the Cognito admin boundary for a valid token.

Flutter tests:

- Reset password initially shows OTP step without password fields.
- Successful OTP verification switches to new-password step.
- Confirm step requires matching and strong passwords.
- Successful confirm navigates back to login.

## Out of Scope

- Do not create a new Cognito User Pool.
- Do not implement fake local-only OTP storage for production.
- Do not compare new password with the old password in forgot-password flow unless the backend has a real password-history mechanism.
