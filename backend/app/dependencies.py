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
