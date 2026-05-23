from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.dependencies import get_repository
from app.main import app


client = TestClient(app)


def setup_function() -> None:
    get_repository.cache_clear()


def test_urgent_shift_lifecycle() -> None:
    employer_headers = {"x-user-id": "employer-1", "x-role": "employer"}
    worker_headers = {"x-user-id": "worker-1", "x-role": "worker"}

    job_payload = {
        "title": "Warehouse packing shift",
        "category": "Logistics",
        "location": {
            "address": "District 7, Ho Chi Minh City",
            "latitude": 10.738,
            "longitude": 106.721,
        },
        "start_time": (datetime.now(UTC) + timedelta(hours=1)).isoformat(),
        "end_time": (datetime.now(UTC) + timedelta(hours=7)).isoformat(),
        "pay_amount": 420000,
        "currency": "VND",
        "required_workers": 1,
    }

    created = client.post(
        "/urgent-jobs",
        json=job_payload,
        headers=employer_headers,
    )
    assert created.status_code == 201
    job_id = created.json()["job_id"]

    published = client.post(
        f"/urgent-jobs/{job_id}/publish",
        headers=employer_headers,
    )
    assert published.status_code == 200
    assert published.json()["status"] == "open"

    claimed = client.post(
        f"/urgent-jobs/{job_id}/claim",
        headers=worker_headers,
    )
    assert claimed.status_code == 200
    booking_id = claimed.json()["booking_id"]
    assert claimed.json()["payment_status"] == "held"

    duplicate_claim = client.post(
        f"/urgent-jobs/{job_id}/claim",
        headers={"x-user-id": "worker-2", "x-role": "worker"},
    )
    assert duplicate_claim.status_code == 409

    checked_in = client.post(
        f"/shift-bookings/{booking_id}/check-in",
        headers=worker_headers,
    )
    assert checked_in.status_code == 200
    assert checked_in.json()["status"] == "checked_in"

    checked_out = client.post(
        f"/shift-bookings/{booking_id}/check-out",
        headers=worker_headers,
    )
    assert checked_out.status_code == 200
    assert checked_out.json()["payment_status"] == "release_pending"

    confirmed = client.post(
        f"/shift-bookings/{booking_id}/confirm",
        headers=employer_headers,
    )
    assert confirmed.status_code == 200
    assert confirmed.json()["status"] == "completed"
    assert confirmed.json()["payment_status"] == "released"
