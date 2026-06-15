from datetime import UTC, datetime

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
