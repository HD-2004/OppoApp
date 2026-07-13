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


# Models dành cho AI Screening & Interview
class CVScreeningRequest(BaseModel):
    job_description: str
    cv_text: str
    cv_url: str | None = None


class CVScreeningResponse(BaseModel):
    score: int = Field(..., description="Điểm số đánh giá từ 0 đến 100")
    result: str = Field(..., description="Kết quả: pass | review | fail")
    strengths: list[str] = Field(..., description="Danh sách điểm mạnh của ứng viên")
    weaknesses: list[str] = Field(..., description="Danh sách điểm yếu hoặc thiếu sót của ứng viên")
    reason: str = Field(..., description="Lý do chi tiết cho đánh giá")


class InterviewSessionStartRequest(BaseModel):
    job_title: str
    job_description: str
    cv_text: str
    cv_url: str | None = None
    custom_questions: list[str] = []


class InterviewSessionStartResponse(BaseModel):
    session_id: str
    question: str


class InterviewAnswerRequest(BaseModel):
    session_id: str
    answer: str


class InterviewReport(BaseModel):
    total_score: int = Field(..., description="Tổng điểm đánh giá cuộc phỏng vấn từ 0 đến 100")
    past_experience_score: int = Field(..., description="Điểm đánh giá về kinh nghiệm làm việc ngành F&B (0-100)")
    situation_handling_score: int = Field(..., description="Điểm giải quyết và xử lý tình huống thực tế (0-100)")
    operations_score: int = Field(..., description="Điểm kiến thức quy trình vận hành F&B và tác phong làm việc (0-100)")
    custom_questions_score: int = Field(..., description="Điểm trả lời các câu hỏi riêng từ Employer (0-100)")
    strengths: list[str] = Field(..., description="Danh sách điểm mạnh rút ra từ cuộc phỏng vấn")
    weaknesses: list[str] = Field(..., description="Danh sách điểm yếu hoặc kỹ năng cần cải thiện")
    recommend_to_employer: bool = Field(..., description="Có khuyên dùng/gửi CV cho Employer không")
    reason: str = Field(..., description="Nhận xét chi tiết tổng quan cuộc phỏng vấn")


class InterviewAnswerResponse(BaseModel):
    question: str | None = Field(default=None, description="Câu hỏi tiếp theo từ AI, là None nếu phỏng vấn kết thúc")
    finished: bool = Field(default=False, description="Đã hoàn thành buổi phỏng vấn hay chưa")
    report: InterviewReport | None = Field(default=None, description="Báo cáo kết quả chi tiết khi finished là True")
