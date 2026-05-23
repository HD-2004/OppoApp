from datetime import datetime
from enum import StrEnum
from typing import Literal

from pydantic import BaseModel, Field


class Role(StrEnum):
    worker = "worker"
    employer = "employer"
    admin = "admin"


class UrgentShiftStatus(StrEnum):
    draft = "draft"
    open = "open"
    filled = "filled"
    in_progress = "in_progress"
    completed = "completed"
    cancelled = "cancelled"


class ShiftBookingStatus(StrEnum):
    accepted = "accepted"
    checked_in = "checked_in"
    checked_out = "checked_out"
    completed = "completed"
    cancelled = "cancelled"
    disputed = "disputed"


class PaymentStatus(StrEnum):
    hold_pending = "hold_pending"
    held = "held"
    release_pending = "release_pending"
    released = "released"
    refund_pending = "refund_pending"
    refunded = "refunded"
    failed = "failed"
    disputed = "disputed"


class Principal(BaseModel):
    user_id: str
    role: Role


class Location(BaseModel):
    address: str
    latitude: float
    longitude: float


class CreateUrgentShiftRequest(BaseModel):
    title: str = Field(min_length=3, max_length=120)
    category: str = Field(min_length=2, max_length=80)
    location: Location
    start_time: datetime
    end_time: datetime
    pay_amount: int = Field(gt=0)
    currency: str = Field(default="VND", min_length=3, max_length=3)
    required_workers: int = Field(gt=0, le=100)


class UrgentShiftJob(BaseModel):
    job_id: str
    employer_id: str
    title: str
    category: str
    location: Location
    start_time: datetime
    end_time: datetime
    pay_amount: int
    currency: str
    required_workers: int
    accepted_workers: int = 0
    status: UrgentShiftStatus = UrgentShiftStatus.draft
    created_at: datetime
    updated_at: datetime


class ShiftBooking(BaseModel):
    booking_id: str
    job_id: str
    worker_id: str
    status: ShiftBookingStatus
    payment_status: PaymentStatus
    check_in_at: datetime | None = None
    check_out_at: datetime | None = None
    employer_confirmed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class DisputeRequest(BaseModel):
    reason: Literal["no_show", "early_leave", "employer_rejected", "payment_issue", "other"]
    note: str = Field(min_length=5, max_length=500)
