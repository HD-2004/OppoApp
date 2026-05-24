from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Ốp Pờ API"
    environment: str = "local"
    aws_region: str = "ap-southeast-1"
    jobs_table_name: str = "OppoTempJobs"
    bookings_table_name: str = "OppoShiftBookings"
    use_in_memory_repo: bool = True


@lru_cache
def get_settings() -> Settings:
    return Settings()
