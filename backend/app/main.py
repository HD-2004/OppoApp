from fastapi import Depends, FastAPI, status
from mangum import Mangum

from .auth import get_current_principal, require_role
from .dependencies import get_repository, get_shift_service
from .models import (
    CreateUrgentShiftRequest,
    DisputeRequest,
    Principal,
    Role,
    ShiftBooking,
    UrgentShiftJob,
)
from .repositories import ShiftRepository
from .services import ShiftService
from .settings import get_settings

settings = get_settings()
app = FastAPI(title=settings.app_name)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.environment}


@app.post(
    "/urgent-jobs",
    response_model=UrgentShiftJob,
    status_code=status.HTTP_201_CREATED,
)
async def create_urgent_job(
    payload: CreateUrgentShiftRequest,
    principal: Principal = Depends(get_current_principal),
    repository: ShiftRepository = Depends(get_repository),
) -> UrgentShiftJob:
    require_role(principal, Role.employer)
    return await repository.create_job(principal.user_id, payload)


@app.post("/urgent-jobs/{job_id}/publish", response_model=UrgentShiftJob)
async def publish_urgent_job(
    job_id: str,
    principal: Principal = Depends(get_current_principal),
    repository: ShiftRepository = Depends(get_repository),
) -> UrgentShiftJob:
    require_role(principal, Role.employer)
    return await repository.publish_job(principal.user_id, job_id)


@app.post("/urgent-jobs/{job_id}/claim", response_model=ShiftBooking)
async def claim_shift(
    job_id: str,
    principal: Principal = Depends(get_current_principal),
    repository: ShiftRepository = Depends(get_repository),
) -> ShiftBooking:
    require_role(principal, Role.worker)
    return await repository.claim_shift(principal.user_id, job_id)


@app.post("/shift-bookings/{booking_id}/check-in", response_model=ShiftBooking)
async def check_in(
    booking_id: str,
    principal: Principal = Depends(get_current_principal),
    service: ShiftService = Depends(get_shift_service),
) -> ShiftBooking:
    require_role(principal, Role.worker)
    return await service.check_in(booking_id, principal.user_id)


@app.post("/shift-bookings/{booking_id}/check-out", response_model=ShiftBooking)
async def check_out(
    booking_id: str,
    principal: Principal = Depends(get_current_principal),
    service: ShiftService = Depends(get_shift_service),
) -> ShiftBooking:
    require_role(principal, Role.worker)
    return await service.check_out(booking_id, principal.user_id)


@app.post("/shift-bookings/{booking_id}/confirm", response_model=ShiftBooking)
async def confirm_booking(
    booking_id: str,
    principal: Principal = Depends(get_current_principal),
    service: ShiftService = Depends(get_shift_service),
) -> ShiftBooking:
    require_role(principal, Role.employer)
    return await service.confirm(booking_id)


@app.post("/shift-bookings/{booking_id}/dispute", response_model=ShiftBooking)
async def dispute_booking(
    booking_id: str,
    payload: DisputeRequest,
    principal: Principal = Depends(get_current_principal),
    service: ShiftService = Depends(get_shift_service),
) -> ShiftBooking:
    require_role(principal, Role.worker, Role.employer)
    _ = payload
    return await service.dispute(booking_id)


handler = Mangum(app)
