from functools import lru_cache

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
