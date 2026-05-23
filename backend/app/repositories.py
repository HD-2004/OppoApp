from abc import ABC, abstractmethod
from datetime import UTC, datetime
from uuid import uuid4

from fastapi import HTTPException, status

from .models import (
    CreateUrgentShiftRequest,
    PaymentStatus,
    ShiftBooking,
    ShiftBookingStatus,
    UrgentShiftJob,
    UrgentShiftStatus,
)


class ShiftRepository(ABC):
    @abstractmethod
    async def create_job(
        self,
        employer_id: str,
        payload: CreateUrgentShiftRequest,
    ) -> UrgentShiftJob:
        raise NotImplementedError

    @abstractmethod
    async def publish_job(self, employer_id: str, job_id: str) -> UrgentShiftJob:
        raise NotImplementedError

    @abstractmethod
    async def claim_shift(self, worker_id: str, job_id: str) -> ShiftBooking:
        raise NotImplementedError

    @abstractmethod
    async def get_booking(self, booking_id: str) -> ShiftBooking:
        raise NotImplementedError

    @abstractmethod
    async def update_booking(self, booking: ShiftBooking) -> ShiftBooking:
        raise NotImplementedError


class InMemoryShiftRepository(ShiftRepository):
    def __init__(self) -> None:
        self.jobs: dict[str, UrgentShiftJob] = {}
        self.bookings: dict[str, ShiftBooking] = {}

    async def create_job(
        self,
        employer_id: str,
        payload: CreateUrgentShiftRequest,
    ) -> UrgentShiftJob:
        now = datetime.now(UTC)
        job = UrgentShiftJob(
            job_id=f"job_{uuid4().hex}",
            employer_id=employer_id,
            title=payload.title,
            category=payload.category,
            location=payload.location,
            start_time=payload.start_time,
            end_time=payload.end_time,
            pay_amount=payload.pay_amount,
            currency=payload.currency,
            required_workers=payload.required_workers,
            created_at=now,
            updated_at=now,
        )
        self.jobs[job.job_id] = job
        return job

    async def publish_job(self, employer_id: str, job_id: str) -> UrgentShiftJob:
        job = self._get_job(job_id)
        if job.employer_id != employer_id:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Not the job owner.")
        if job.status != UrgentShiftStatus.draft:
            raise HTTPException(status.HTTP_409_CONFLICT, "Only draft jobs can publish.")
        updated = job.model_copy(
            update={
                "status": UrgentShiftStatus.open,
                "updated_at": datetime.now(UTC),
            }
        )
        self.jobs[job_id] = updated
        return updated

    async def claim_shift(self, worker_id: str, job_id: str) -> ShiftBooking:
        job = self._get_job(job_id)
        if job.status != UrgentShiftStatus.open:
            raise HTTPException(status.HTTP_409_CONFLICT, "Shift is not open.")
        if job.accepted_workers >= job.required_workers:
            raise HTTPException(status.HTTP_409_CONFLICT, "Shift is already filled.")

        accepted_workers = job.accepted_workers + 1
        job_status = (
            UrgentShiftStatus.filled
            if accepted_workers == job.required_workers
            else UrgentShiftStatus.open
        )
        self.jobs[job_id] = job.model_copy(
            update={
                "accepted_workers": accepted_workers,
                "status": job_status,
                "updated_at": datetime.now(UTC),
            }
        )

        now = datetime.now(UTC)
        booking = ShiftBooking(
            booking_id=f"booking_{uuid4().hex}",
            job_id=job_id,
            worker_id=worker_id,
            status=ShiftBookingStatus.accepted,
            payment_status=PaymentStatus.held,
            created_at=now,
            updated_at=now,
        )
        self.bookings[booking.booking_id] = booking
        return booking

    async def get_booking(self, booking_id: str) -> ShiftBooking:
        booking = self.bookings.get(booking_id)
        if booking is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Booking not found.")
        return booking

    async def update_booking(self, booking: ShiftBooking) -> ShiftBooking:
        self.bookings[booking.booking_id] = booking.model_copy(
            update={"updated_at": datetime.now(UTC)}
        )
        return self.bookings[booking.booking_id]

    def _get_job(self, job_id: str) -> UrgentShiftJob:
        job = self.jobs.get(job_id)
        if job is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Shift not found.")
        return job


class DynamoDbShiftRepository(ShiftRepository):
    """Production repository boundary.

    Implement this with DynamoDB TransactWriteItems and conditional updates:
    job claims must atomically increment accepted_workers only when status=open
    and accepted_workers < required_workers, then create the booking ledger item.
    """

    def __init__(self, jobs_table_name: str, bookings_table_name: str) -> None:
        self.jobs_table_name = jobs_table_name
        self.bookings_table_name = bookings_table_name

    async def create_job(
        self,
        employer_id: str,
        payload: CreateUrgentShiftRequest,
    ) -> UrgentShiftJob:
        raise NotImplementedError("Wire boto3 PutItem before production deploy.")

    async def publish_job(self, employer_id: str, job_id: str) -> UrgentShiftJob:
        raise NotImplementedError("Wire conditional UpdateItem before production deploy.")

    async def claim_shift(self, worker_id: str, job_id: str) -> ShiftBooking:
        raise NotImplementedError("Wire TransactWriteItems before production deploy.")

    async def get_booking(self, booking_id: str) -> ShiftBooking:
        raise NotImplementedError("Wire GetItem before production deploy.")

    async def update_booking(self, booking: ShiftBooking) -> ShiftBooking:
        raise NotImplementedError("Wire conditional UpdateItem before production deploy.")
