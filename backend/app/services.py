from datetime import UTC, datetime

from fastapi import HTTPException, status

from .models import PaymentStatus, ShiftBooking, ShiftBookingStatus
from .repositories import ShiftRepository


class ShiftService:
    def __init__(self, repository: ShiftRepository) -> None:
        self.repository = repository

    async def check_in(self, booking_id: str, worker_id: str) -> ShiftBooking:
        booking = await self._get_worker_booking(booking_id, worker_id)
        self._require_status(booking, ShiftBookingStatus.accepted)
        return await self.repository.update_booking(
            booking.model_copy(
                update={
                    "status": ShiftBookingStatus.checked_in,
                    "check_in_at": datetime.now(UTC),
                }
            )
        )

    async def check_out(self, booking_id: str, worker_id: str) -> ShiftBooking:
        booking = await self._get_worker_booking(booking_id, worker_id)
        self._require_status(booking, ShiftBookingStatus.checked_in)
        return await self.repository.update_booking(
            booking.model_copy(
                update={
                    "status": ShiftBookingStatus.checked_out,
                    "payment_status": PaymentStatus.release_pending,
                    "check_out_at": datetime.now(UTC),
                }
            )
        )

    async def confirm(self, booking_id: str) -> ShiftBooking:
        booking = await self.repository.get_booking(booking_id)
        self._require_status(booking, ShiftBookingStatus.checked_out)
        return await self.repository.update_booking(
            booking.model_copy(
                update={
                    "status": ShiftBookingStatus.completed,
                    "payment_status": PaymentStatus.released,
                    "employer_confirmed_at": datetime.now(UTC),
                }
            )
        )

    async def dispute(self, booking_id: str) -> ShiftBooking:
        booking = await self.repository.get_booking(booking_id)
        if booking.status in {ShiftBookingStatus.completed, ShiftBookingStatus.disputed}:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "Completed or already disputed bookings cannot be disputed.",
            )
        return await self.repository.update_booking(
            booking.model_copy(
                update={
                    "status": ShiftBookingStatus.disputed,
                    "payment_status": PaymentStatus.disputed,
                }
            )
        )

    async def _get_worker_booking(self, booking_id: str, worker_id: str) -> ShiftBooking:
        booking = await self.repository.get_booking(booking_id)
        if booking.worker_id != worker_id:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Not the booking worker.")
        return booking

    def _require_status(
        self,
        booking: ShiftBooking,
        expected: ShiftBookingStatus,
    ) -> None:
        if booking.status != expected:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                f"Expected {expected.value}, got {booking.status.value}.",
            )
