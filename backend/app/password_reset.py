from __future__ import annotations

import hashlib
import hmac
import secrets
from dataclasses import dataclass, replace
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from typing import Callable, Protocol
from uuid import uuid4

import boto3
from boto3.dynamodb.conditions import Key
from fastapi import HTTPException, status
from pydantic import BaseModel, Field


class PasswordResetStatus(StrEnum):
    pending = "pending"
    verified = "verified"
    consumed = "consumed"


class PasswordResetRequest(BaseModel):
    email: str = Field(min_length=3, max_length=254)


class PasswordResetVerifyRequest(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    otp: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")


class PasswordResetVerifyResponse(BaseModel):
    resetToken: str


class PasswordResetConfirmRequest(BaseModel):
    email: str = Field(min_length=3, max_length=254)
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
                replace(challenge, attempts=challenge.attempts + 1)
            )
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "invalid_or_expired_otp")

        reset_token = secrets.token_urlsafe(32)
        await self.repository.update_challenge(
            replace(
                challenge,
                status=PasswordResetStatus.verified,
                reset_token_hash=self._hash(f"token:{normalized}:{reset_token}"),
                verified_at=now,
                expires_at=now + timedelta(minutes=10),
            )
        )
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
            replace(
                challenge,
                status=PasswordResetStatus.consumed,
                consumed_at=now,
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
            KeyConditionExpression=Key("email").eq(email),
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
            reset_token_hash=str(item["resetTokenHash"])
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
