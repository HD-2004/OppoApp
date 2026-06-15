# Reset Password Backend OTP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real backend OTP reset-password flow and split Flutter reset password into OTP verification followed by password update.

**Architecture:** FastAPI exposes three password-reset endpoints backed by DynamoDB, SES, and Cognito admin APIs. Flutter stops using Amplify's managed reset-code flow for forgot password and instead calls the backend contract through a focused HTTP client. Tests inject fake backend boundaries only in test code while production dependencies require real AWS configuration.

**Tech Stack:** Python FastAPI, boto3 DynamoDB/SES/Cognito IDP, pytest/TestClient, Flutter/Riverpod, http package, widget tests.

---

## File Structure

- Create `backend/app/password_reset.py`: Pydantic models, service logic, hash/token helpers, backend boundary protocols, DynamoDB/SES/Cognito implementations.
- Modify `backend/app/settings.py`: add required password-reset AWS settings.
- Modify `backend/app/dependencies.py`: provide production `PasswordResetService` using DynamoDB, SES, and Cognito.
- Modify `backend/app/main.py`: add `/auth/password-reset/request`, `/auth/password-reset/verify`, and `/auth/password-reset/confirm`.
- Create `backend/tests/test_password_reset_flow.py`: endpoint tests with injected fake repository/sender/Cognito boundaries.
- Create `lib/features/auth/data/password_reset_api.dart`: Flutter HTTP client for request/verify/confirm.
- Modify `lib/features/auth/application/auth_controller.dart`: expose request, verify, and confirm methods.
- Modify `lib/features/auth/presentation/forgot_password_screen.dart`: send OTP through backend request endpoint.
- Modify `lib/features/auth/presentation/reset_password_screen.dart`: split into OTP step and new-password step.
- Modify `lib/core/localization/app_localizations.dart`, `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`: add reset OTP messages.
- Create or update `test/reset_password_screen_test.dart`: widget coverage for the split flow.

---

### Task 1: Backend Password Reset Service

**Files:**
- Create: `backend/app/password_reset.py`
- Modify: `backend/app/settings.py`
- Modify: `backend/app/dependencies.py`
- Test: `backend/tests/test_password_reset_flow.py`

- [ ] **Step 1: Write failing backend tests**

Create `backend/tests/test_password_reset_flow.py` with fake boundaries:

```python
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.dependencies import get_password_reset_service
from app.main import app
from app.password_reset import (
    PasswordResetChallenge,
    PasswordResetService,
    PasswordResetStatus,
)


class FakePasswordResetRepository:
    def __init__(self) -> None:
        self.challenge: PasswordResetChallenge | None = None

    async def save_challenge(self, challenge: PasswordResetChallenge) -> None:
        self.challenge = challenge

    async def get_latest_active_challenge(
        self,
        email: str,
        now: datetime,
    ) -> PasswordResetChallenge | None:
        if self.challenge is None:
            return None
        if self.challenge.email != email:
            return None
        if self.challenge.expires_at <= now:
            return None
        if self.challenge.status == PasswordResetStatus.consumed:
            return None
        return self.challenge

    async def update_challenge(self, challenge: PasswordResetChallenge) -> None:
        self.challenge = challenge


class FakeOtpSender:
    def __init__(self) -> None:
        self.sent: list[tuple[str, str]] = []

    async def send_otp(self, email: str, otp: str) -> None:
        self.sent.append((email, otp))


class FakePasswordUpdater:
    def __init__(self) -> None:
        self.updated: list[tuple[str, str]] = []

    async def set_user_password(self, email: str, new_password: str) -> None:
        self.updated.append((email, new_password))


def build_service() -> tuple[
    PasswordResetService,
    FakePasswordResetRepository,
    FakeOtpSender,
    FakePasswordUpdater,
]:
    repo = FakePasswordResetRepository()
    sender = FakeOtpSender()
    updater = FakePasswordUpdater()
    service = PasswordResetService(
        repository=repo,
        otp_sender=sender,
        password_updater=updater,
        secret="test-secret",
        now=lambda: datetime(2026, 6, 15, tzinfo=UTC),
    )
    return service, repo, sender, updater


def override_service(service: PasswordResetService) -> None:
    app.dependency_overrides[get_password_reset_service] = lambda: service


def teardown_function() -> None:
    app.dependency_overrides.clear()


def test_request_stores_hashed_otp_and_sends_email() -> None:
    service, repo, sender, _ = build_service()
    override_service(service)
    client = TestClient(app)

    response = client.post(
        "/auth/password-reset/request",
        json={"email": " USER@example.com "},
    )

    assert response.status_code == 200
    assert response.json() == {"success": True}
    assert repo.challenge is not None
    assert repo.challenge.email == "user@example.com"
    assert repo.challenge.otp_hash != sender.sent[0][1]
    assert sender.sent[0][0] == "user@example.com"


def test_verify_rejects_wrong_otp_and_increments_attempts() -> None:
    service, repo, sender, _ = build_service()
    override_service(service)
    client = TestClient(app)
    client.post("/auth/password-reset/request", json={"email": "user@example.com"})

    response = client.post(
        "/auth/password-reset/verify",
        json={"email": "user@example.com", "otp": "000000"},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "invalid_or_expired_otp"
    assert repo.challenge is not None
    assert repo.challenge.attempts == 1
    assert sender.sent


def test_verify_returns_reset_token_for_valid_otp() -> None:
    service, repo, sender, _ = build_service()
    override_service(service)
    client = TestClient(app)
    client.post("/auth/password-reset/request", json={"email": "user@example.com"})
    otp = sender.sent[0][1]

    response = client.post(
        "/auth/password-reset/verify",
        json={"email": "user@example.com", "otp": otp},
    )

    assert response.status_code == 200
    assert response.json()["resetToken"]
    assert repo.challenge is not None
    assert repo.challenge.status == PasswordResetStatus.verified
    assert repo.challenge.reset_token_hash is not None


def test_confirm_rejects_used_token() -> None:
    service, _, sender, _ = build_service()
    override_service(service)
    client = TestClient(app)
    client.post("/auth/password-reset/request", json={"email": "user@example.com"})
    otp = sender.sent[0][1]
    token = client.post(
        "/auth/password-reset/verify",
        json={"email": "user@example.com", "otp": otp},
    ).json()["resetToken"]

    first = client.post(
        "/auth/password-reset/confirm",
        json={
            "email": "user@example.com",
            "resetToken": token,
            "newPassword": "NewPassword123!",
        },
    )
    second = client.post(
        "/auth/password-reset/confirm",
        json={
            "email": "user@example.com",
            "resetToken": token,
            "newPassword": "NewPassword123!",
        },
    )

    assert first.status_code == 200
    assert second.status_code == 400
    assert second.json()["detail"] == "invalid_or_expired_reset_session"


def test_confirm_calls_password_updater_for_valid_token() -> None:
    service, repo, sender, updater = build_service()
    override_service(service)
    client = TestClient(app)
    client.post("/auth/password-reset/request", json={"email": "user@example.com"})
    otp = sender.sent[0][1]
    token = client.post(
        "/auth/password-reset/verify",
        json={"email": "user@example.com", "otp": otp},
    ).json()["resetToken"]

    response = client.post(
        "/auth/password-reset/confirm",
        json={
            "email": "user@example.com",
            "resetToken": token,
            "newPassword": "NewPassword123!",
        },
    )

    assert response.status_code == 200
    assert response.json() == {"success": True}
    assert updater.updated == [("user@example.com", "NewPassword123!")]
    assert repo.challenge is not None
    assert repo.challenge.status == PasswordResetStatus.consumed
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd backend
pytest tests/test_password_reset_flow.py -q
```

Expected: FAIL because `app.password_reset` and `get_password_reset_service` do not exist.

- [ ] **Step 3: Implement backend service and production boundaries**

Create `backend/app/password_reset.py` with:

```python
from __future__ import annotations

import hashlib
import hmac
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from typing import Callable, Protocol
from uuid import uuid4

import boto3
from fastapi import HTTPException, status
from pydantic import BaseModel, EmailStr, Field


class PasswordResetStatus(StrEnum):
    pending = "pending"
    verified = "verified"
    consumed = "consumed"


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordResetVerifyRequest(BaseModel):
    email: EmailStr
    otp: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")


class PasswordResetVerifyResponse(BaseModel):
    resetToken: str


class PasswordResetConfirmRequest(BaseModel):
    email: EmailStr
    resetToken: str = Field(min_length=32)
    newPassword: str = Field(min_length=8, max_length=256)


class PasswordResetSuccessResponse(BaseModel):
    success: bool = True


@dataclass(frozen=True)
class PasswordResetChallenge:
    email: str
    challenge_id: str
    otp_hash: str
    reset_token_hash: str | None
    status: PasswordResetStatus
    attempts: int
    created_at: datetime
    expires_at: datetime
    verified_at: datetime | None = None
    consumed_at: datetime | None = None


class PasswordResetRepository(Protocol):
    async def save_challenge(self, challenge: PasswordResetChallenge) -> None:
        ...

    async def get_latest_active_challenge(
        self,
        email: str,
        now: datetime,
    ) -> PasswordResetChallenge | None:
        ...

    async def update_challenge(self, challenge: PasswordResetChallenge) -> None:
        ...


class OtpSender(Protocol):
    async def send_otp(self, email: str, otp: str) -> None:
        ...


class PasswordUpdater(Protocol):
    async def set_user_password(self, email: str, new_password: str) -> None:
        ...


def normalize_email(email: str) -> str:
    return email.strip().lower()


def validate_cognito_password(password: str) -> None:
    if (
        len(password) < 8
        or not any(c.islower() for c in password)
        or not any(c.isupper() for c in password)
        or not any(c.isdigit() for c in password)
        or not any(not c.isalnum() for c in password)
    ):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "weak_password")


class PasswordResetService:
    def __init__(
        self,
        repository: PasswordResetRepository,
        otp_sender: OtpSender,
        password_updater: PasswordUpdater,
        secret: str,
        now: Callable[[], datetime] | None = None,
    ) -> None:
        if not secret:
            raise ValueError("Password reset secret is required.")
        self.repository = repository
        self.otp_sender = otp_sender
        self.password_updater = password_updater
        self.secret = secret
        self.now = now or (lambda: datetime.now(UTC))

    async def request_reset(self, email: str) -> PasswordResetSuccessResponse:
        normalized = normalize_email(email)
        now = self.now()
        otp = f"{secrets.randbelow(1_000_000):06d}"
        challenge = PasswordResetChallenge(
            email=normalized,
            challenge_id=f"reset_{uuid4().hex}",
            otp_hash=self._hash(f"otp:{normalized}:{otp}"),
            reset_token_hash=None,
            status=PasswordResetStatus.pending,
            attempts=0,
            created_at=now,
            expires_at=now + timedelta(minutes=10),
        )
        await self.repository.save_challenge(challenge)
        await self.otp_sender.send_otp(normalized, otp)
        return PasswordResetSuccessResponse()

    async def verify_otp(
        self,
        email: str,
        otp: str,
    ) -> PasswordResetVerifyResponse:
        normalized = normalize_email(email)
        now = self.now()
        challenge = await self.repository.get_latest_active_challenge(
            normalized,
            now,
        )
        if (
            challenge is None
            or challenge.status != PasswordResetStatus.pending
            or challenge.attempts >= 5
        ):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "invalid_or_expired_otp")

        expected_hash = self._hash(f"otp:{normalized}:{otp}")
        if not hmac.compare_digest(challenge.otp_hash, expected_hash):
            await self.repository.update_challenge(
                PasswordResetChallenge(
                    **{
                        **challenge.__dict__,
                        "attempts": challenge.attempts + 1,
                    }
                )
            )
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "invalid_or_expired_otp")

        reset_token = secrets.token_urlsafe(32)
        updated = PasswordResetChallenge(
            **{
                **challenge.__dict__,
                "status": PasswordResetStatus.verified,
                "reset_token_hash": self._hash(f"token:{normalized}:{reset_token}"),
                "verified_at": now,
                "expires_at": now + timedelta(minutes=10),
            }
        )
        await self.repository.update_challenge(updated)
        return PasswordResetVerifyResponse(resetToken=reset_token)

    async def confirm_reset(
        self,
        email: str,
        reset_token: str,
        new_password: str,
    ) -> PasswordResetSuccessResponse:
        validate_cognito_password(new_password)
        normalized = normalize_email(email)
        now = self.now()
        challenge = await self.repository.get_latest_active_challenge(
            normalized,
            now,
        )
        if (
            challenge is None
            or challenge.status != PasswordResetStatus.verified
            or challenge.reset_token_hash is None
        ):
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "invalid_or_expired_reset_session",
            )

        token_hash = self._hash(f"token:{normalized}:{reset_token}")
        if not hmac.compare_digest(challenge.reset_token_hash, token_hash):
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "invalid_or_expired_reset_session",
            )

        await self.password_updater.set_user_password(normalized, new_password)
        await self.repository.update_challenge(
            PasswordResetChallenge(
                **{
                    **challenge.__dict__,
                    "status": PasswordResetStatus.consumed,
                    "consumed_at": now,
                }
            )
        )
        return PasswordResetSuccessResponse()

    def _hash(self, value: str) -> str:
        return hmac.new(
            self.secret.encode("utf-8"),
            value.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()


class DynamoDbPasswordResetRepository:
    def __init__(self, table_name: str, region_name: str) -> None:
        self.table = boto3.resource("dynamodb", region_name=region_name).Table(
            table_name
        )

    async def save_challenge(self, challenge: PasswordResetChallenge) -> None:
        self.table.put_item(Item=self._to_item(challenge))

    async def get_latest_active_challenge(
        self,
        email: str,
        now: datetime,
    ) -> PasswordResetChallenge | None:
        response = self.table.query(
            KeyConditionExpression="email = :email",
            ExpressionAttributeValues={":email": email},
            ScanIndexForward=False,
            Limit=10,
        )
        for item in response.get("Items", []):
            challenge = self._from_item(item)
            if (
                challenge.expires_at > now
                and challenge.status != PasswordResetStatus.consumed
            ):
                return challenge
        return None

    async def update_challenge(self, challenge: PasswordResetChallenge) -> None:
        self.table.put_item(Item=self._to_item(challenge))

    def _to_item(self, challenge: PasswordResetChallenge) -> dict[str, object]:
        return {
            "email": challenge.email,
            "challengeId": challenge.challenge_id,
            "otpHash": challenge.otp_hash,
            "resetTokenHash": challenge.reset_token_hash,
            "status": challenge.status.value,
            "attempts": challenge.attempts,
            "createdAt": challenge.created_at.isoformat(),
            "expiresAt": int(challenge.expires_at.timestamp()),
            "expiresAtIso": challenge.expires_at.isoformat(),
            "verifiedAt": challenge.verified_at.isoformat()
            if challenge.verified_at
            else None,
            "consumedAt": challenge.consumed_at.isoformat()
            if challenge.consumed_at
            else None,
        }

    def _from_item(self, item: dict[str, object]) -> PasswordResetChallenge:
        return PasswordResetChallenge(
            email=str(item["email"]),
            challenge_id=str(item["challengeId"]),
            otp_hash=str(item["otpHash"]),
            reset_token_hash=item.get("resetTokenHash")
            if item.get("resetTokenHash")
            else None,
            status=PasswordResetStatus(str(item["status"])),
            attempts=int(item["attempts"]),
            created_at=datetime.fromisoformat(str(item["createdAt"])),
            expires_at=datetime.fromtimestamp(int(item["expiresAt"]), tz=UTC),
            verified_at=datetime.fromisoformat(str(item["verifiedAt"]))
            if item.get("verifiedAt")
            else None,
            consumed_at=datetime.fromisoformat(str(item["consumedAt"]))
            if item.get("consumedAt")
            else None,
        )


class SesOtpSender:
    def __init__(self, sender_email: str, region_name: str) -> None:
        self.sender_email = sender_email
        self.client = boto3.client("ses", region_name=region_name)

    async def send_otp(self, email: str, otp: str) -> None:
        self.client.send_email(
            Source=self.sender_email,
            Destination={"ToAddresses": [email]},
            Message={
                "Subject": {"Data": "Ma xac nhan dat lai mat khau"},
                "Body": {
                    "Text": {
                        "Data": (
                            "Ma OTP dat lai mat khau cua ban la "
                            f"{otp}. Ma co hieu luc trong 10 phut."
                        )
                    }
                },
            },
        )


class CognitoPasswordUpdater:
    def __init__(self, user_pool_id: str, region_name: str) -> None:
        self.user_pool_id = user_pool_id
        self.client = boto3.client("cognito-idp", region_name=region_name)

    async def set_user_password(self, email: str, new_password: str) -> None:
        self.client.admin_set_user_password(
            UserPoolId=self.user_pool_id,
            Username=email,
            Password=new_password,
            Permanent=True,
        )
```

Modify `backend/app/settings.py`:

```python
class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Ốp Pờ API"
    environment: str = "local"
    aws_region: str = "ap-southeast-1"
    jobs_table_name: str = "OppoTempJobs"
    bookings_table_name: str = "OppoShiftBookings"
    use_in_memory_repo: bool = True
    password_reset_table_name: str = "OppoPasswordResetChallenges"
    password_reset_secret: str = ""
    cognito_user_pool_id: str = ""
    ses_sender_email: str = ""
```

Modify `backend/app/dependencies.py`:

```python
from functools import lru_cache

from .password_reset import (
    CognitoPasswordUpdater,
    DynamoDbPasswordResetRepository,
    PasswordResetService,
    SesOtpSender,
)
from .repositories import DynamoDbShiftRepository, InMemoryShiftRepository, ShiftRepository
from .services import ShiftService
from .settings import get_settings


@lru_cache
def get_repository() -> ShiftRepository:
    settings = get_settings()
    if settings.use_in_memory_repo:
        return InMemoryShiftRepository()
    return DynamoDbShiftRepository(
        jobs_table_name=settings.jobs_table_name,
        bookings_table_name=settings.bookings_table_name,
    )


def get_shift_service() -> ShiftService:
    return ShiftService(get_repository())


@lru_cache
def get_password_reset_service() -> PasswordResetService:
    settings = get_settings()
    missing = [
        name
        for name, value in {
            "password_reset_secret": settings.password_reset_secret,
            "cognito_user_pool_id": settings.cognito_user_pool_id,
            "ses_sender_email": settings.ses_sender_email,
            "password_reset_table_name": settings.password_reset_table_name,
        }.items()
        if not value
    ]
    if missing:
        raise RuntimeError(
            "Missing password reset backend settings: " + ", ".join(missing)
        )

    return PasswordResetService(
        repository=DynamoDbPasswordResetRepository(
            settings.password_reset_table_name,
            settings.aws_region,
        ),
        otp_sender=SesOtpSender(settings.ses_sender_email, settings.aws_region),
        password_updater=CognitoPasswordUpdater(
            settings.cognito_user_pool_id,
            settings.aws_region,
        ),
        secret=settings.password_reset_secret,
    )
```

- [ ] **Step 4: Run backend tests**

Run:

```powershell
cd backend
pytest tests/test_password_reset_flow.py -q
```

Expected: PASS.

---

### Task 2: Backend Routes

**Files:**
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_password_reset_flow.py`

- [ ] **Step 1: Add route imports and handlers**

Modify `backend/app/main.py` imports:

```python
from .dependencies import get_password_reset_service, get_repository, get_shift_service
from .password_reset import (
    PasswordResetConfirmRequest,
    PasswordResetRequest,
    PasswordResetService,
    PasswordResetSuccessResponse,
    PasswordResetVerifyRequest,
    PasswordResetVerifyResponse,
)
```

Add before urgent jobs routes:

```python
@app.post(
    "/auth/password-reset/request",
    response_model=PasswordResetSuccessResponse,
)
async def request_password_reset(
    payload: PasswordResetRequest,
    service: PasswordResetService = Depends(get_password_reset_service),
) -> PasswordResetSuccessResponse:
    return await service.request_reset(payload.email)


@app.post(
    "/auth/password-reset/verify",
    response_model=PasswordResetVerifyResponse,
)
async def verify_password_reset_otp(
    payload: PasswordResetVerifyRequest,
    service: PasswordResetService = Depends(get_password_reset_service),
) -> PasswordResetVerifyResponse:
    return await service.verify_otp(payload.email, payload.otp)


@app.post(
    "/auth/password-reset/confirm",
    response_model=PasswordResetSuccessResponse,
)
async def confirm_password_reset(
    payload: PasswordResetConfirmRequest,
    service: PasswordResetService = Depends(get_password_reset_service),
) -> PasswordResetSuccessResponse:
    return await service.confirm_reset(
        payload.email,
        payload.resetToken,
        payload.newPassword,
    )
```

- [ ] **Step 2: Run full backend tests**

Run:

```powershell
cd backend
pytest -q
```

Expected: PASS.

---

### Task 3: Flutter Password Reset API Client

**Files:**
- Create: `lib/features/auth/data/password_reset_api.dart`
- Modify: `lib/features/auth/application/auth_controller.dart`
- Test: `test/password_reset_api_test.dart`

- [ ] **Step 1: Write API client tests**

Create `test/password_reset_api_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oppo_app/core/errors/auth_failure.dart';
import 'package:oppo_app/features/auth/data/password_reset_api.dart';

void main() {
  test('verifyOtp returns reset token', () async {
    final api = PasswordResetApi(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/auth/password-reset/verify');
        expect(jsonDecode(request.body), {
          'email': 'user@example.com',
          'otp': '123456',
        });
        return http.Response(jsonEncode({'resetToken': 'token-123'}), 200);
      }),
    );

    final token = await api.verifyOtp(
      email: ' user@example.com ',
      otp: '123456',
    );

    expect(token, 'token-123');
  });

  test('maps invalid otp error to auth failure message', () async {
    final api = PasswordResetApi(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        return http.Response(jsonEncode({'detail': 'invalid_or_expired_otp'}), 400);
      }),
    );

    expect(
      () => api.verifyOtp(email: 'user@example.com', otp: '000000'),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'message',
          'Mã OTP không đúng hoặc đã hết hạn.',
        ),
      ),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/password_reset_api_test.dart
```

Expected: FAIL because `PasswordResetApi` does not exist.

- [ ] **Step 3: Implement API client**

Create `lib/features/auth/data/password_reset_api.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/errors/auth_failure.dart';

class PasswordResetApi {
  PasswordResetApi({
    http.Client? client,
    String baseUrl = defaultBaseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl;

  static const defaultBaseUrl =
      'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod';

  final http.Client _client;
  final String _baseUrl;

  Future<void> requestOtp({required String email}) async {
    final response = await _post(
      '/auth/password-reset/request',
      {'email': email.trim()},
    );
    if (response.statusCode != 200) {
      throw _mapFailure(response);
    }
  }

  Future<String> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _post(
      '/auth/password-reset/verify',
      {'email': email.trim(), 'otp': otp.trim()},
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['resetToken'] as String;
    }
    throw _mapFailure(response);
  }

  Future<void> confirmResetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    final response = await _post(
      '/auth/password-reset/confirm',
      {
        'email': email.trim(),
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );
    if (response.statusCode != 200) {
      throw _mapFailure(response);
    }
  }

  Future<http.Response> _post(String path, Map<String, String> body) {
    return _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  AuthFailure _mapFailure(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail']?.toString();
      if (detail == 'invalid_or_expired_otp') {
        return AuthFailure(
          code: detail,
          message: 'Mã OTP không đúng hoặc đã hết hạn.',
        );
      }
      if (detail == 'invalid_or_expired_reset_session') {
        return AuthFailure(
          code: detail,
          message: 'Phiên đổi mật khẩu đã hết hạn. Vui lòng xác thực OTP lại.',
        );
      }
      if (detail == 'weak_password') {
        return AuthFailure(
          code: detail,
          message: 'Mật khẩu không đáp ứng yêu cầu bảo mật.',
        );
      }
    } catch (_) {
      // Fall through to generic error.
    }
    return AuthFailure(
      code: 'password_reset_failed',
      message: 'Không thể đặt lại mật khẩu. Vui lòng thử lại.',
    );
  }
}
```

- [ ] **Step 4: Wire provider and controller**

Modify `lib/features/auth/application/auth_controller.dart`:

```dart
import '../data/password_reset_api.dart';

final passwordResetApiProvider = Provider<PasswordResetApi>((ref) {
  return PasswordResetApi();
});

Future<void> resetPassword({required String email}) {
  return ref.read(passwordResetApiProvider).requestOtp(email: email);
}

Future<String> verifyResetPasswordOtp({
  required String email,
  required String otp,
}) {
  return ref
      .read(passwordResetApiProvider)
      .verifyOtp(email: email, otp: otp);
}

Future<void> confirmResetPasswordWithToken({
  required String email,
  required String resetToken,
  required String newPassword,
}) {
  return ref.read(passwordResetApiProvider).confirmResetPassword(
        email: email,
        resetToken: resetToken,
        newPassword: newPassword,
      );
}
```

Keep the old `confirmResetPassword` method only if another screen still references it; otherwise replace calls.

- [ ] **Step 5: Run API tests**

Run:

```powershell
flutter test test/password_reset_api_test.dart
```

Expected: PASS.

---

### Task 4: Flutter Split Reset Password UI

**Files:**
- Modify: `lib/features/auth/presentation/reset_password_screen.dart`
- Modify: `lib/core/localization/app_localizations.dart`
- Modify: `lib/l10n/app_vi.arb`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/reset_password_screen_test.dart`

- [ ] **Step 1: Write widget tests**

Create or update `test/reset_password_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oppo_app/features/auth/application/auth_controller.dart';
import 'package:oppo_app/features/auth/data/password_reset_api.dart';
import 'package:oppo_app/features/auth/presentation/reset_password_screen.dart';

class FakePasswordResetApi extends PasswordResetApi {
  @override
  Future<String> verifyOtp({required String email, required String otp}) async {
    return 'verified-token';
  }

  @override
  Future<void> confirmResetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {}
}

Widget buildApp() {
  final router = GoRouter(
    initialLocation: '/reset-password',
    routes: [
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => const ResetPasswordScreen(email: 'user@example.com'),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      passwordResetApiProvider.overrideWithValue(FakePasswordResetApi()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('initial reset screen shows otp step without password fields', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('Mã xác nhận OTP'), findsOneWidget);
    expect(find.text('Mật khẩu mới'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Mật khẩu mới'), findsNothing);
    expect(find.text('Xác thực OTP'), findsOneWidget);
  });

  testWidgets('successful otp verification opens new password step', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('Xác thực OTP'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Mật khẩu mới'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Xác nhận mật khẩu mới'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run widget test to verify it fails**

Run:

```powershell
flutter test test/reset_password_screen_test.dart
```

Expected: FAIL because the screen still shows OTP and password fields together.

- [ ] **Step 3: Add localization messages**

Add Vietnamese entries:

```dart
'verifyOtp': 'Xác thực OTP',
'otpInvalidOrExpired': 'Mã OTP không đúng hoặc đã hết hạn.',
'resetSessionExpired': 'Phiên đổi mật khẩu đã hết hạn. Vui lòng xác thực OTP lại.',
```

Add English entries:

```dart
'verifyOtp': 'Verify OTP',
'otpInvalidOrExpired': 'The OTP is incorrect or has expired.',
'resetSessionExpired': 'Your reset session has expired. Please verify OTP again.',
```

- [ ] **Step 4: Refactor `ResetPasswordScreen` into two states**

In `lib/features/auth/presentation/reset_password_screen.dart`:

- Add `_ResetPasswordStep { otp, password }`.
- Track `_step = _ResetPasswordStep.otp`.
- Track `_resetToken`.
- Change `_updateSubmitState` so OTP step requires email and 6-digit OTP; password step requires password and confirm password.
- Add `_verifyOtp()` that validates email/OTP, calls `verifyResetPasswordOtp`, stores token, clears submit loading, switches to password step.
- Change `_submit()` to call `confirmResetPasswordWithToken` and require `_resetToken`.
- Build OTP-only content when `_step == otp`.
- Build password-only content when `_step == password`.
- Set `AuthTimeline(activeIndex: _step == otp ? 1 : 2)`.
- Use button label `Xác thực OTP` in OTP step and `Đổi mật khẩu` in password step.

- [ ] **Step 5: Run widget tests**

Run:

```powershell
flutter test test/reset_password_screen_test.dart
```

Expected: PASS.

---

### Task 5: Final Verification

**Files:**
- All modified files

- [ ] **Step 1: Run backend tests**

Run:

```powershell
cd backend
pytest -q
```

Expected: PASS.

- [ ] **Step 2: Run Dart analyzer**

Run:

```powershell
dart analyze
```

Expected: no analyzer errors.

- [ ] **Step 3: Run Flutter tests**

Run:

```powershell
flutter test
```

Expected: PASS.

- [ ] **Step 4: Report config needed for production**

Final notes must list the required backend environment variables:

```text
PASSWORD_RESET_SECRET
COGNITO_USER_POOL_ID
SES_SENDER_EMAIL
PASSWORD_RESET_TABLE_NAME
AWS_REGION
```

Also note that DynamoDB TTL must be enabled on `expiresAt`, and the backend deploy role needs DynamoDB read/write, SES send email, and Cognito `AdminSetUserPassword`.
