# AI Agent Guide

## Project Overview
Oppo Temp Jobs is a temporary job recruitment app. V1 prioritizes urgent shift-based work: employers publish short shifts, workers claim available slots, workers check in/out, employers confirm completion, and payment state moves through an escrow-like ledger.

Part-time jobs, interview flows, signed agreements, CV storage, and AI matching are planned after the urgent shift flow is stable.

## Stack Responsibilities
- Flutter: mobile UI, role navigation, mocked-first feature flows, Amplify client integration.
- AWS Amplify: Cognito auth, AppSync real-time subscriptions, GraphQL models, S3 later for documents.
- FastAPI: command workflows, state validation, shift lifecycle, disputes, payment-state transitions.
- DynamoDB: source of truth for jobs, bookings, profiles, and payment ledger records.

## Flutter Conventions
- Use feature-first folders under `lib/features`.
- Keep domain models in `domain`, providers in `application`, repositories in `data`, and widgets/screens in `presentation`.
- Use Riverpod for state and repository injection.
- Use go_router for navigation.
- Start with mocked repositories when backend contracts are still moving; replace with API/AppSync repositories behind the same interface.
- Do not put high-risk business transitions directly in the UI. Send those commands to FastAPI.

## Backend Conventions
- Keep request and response contracts in `backend/app/models.py`.
- Keep role checks in `backend/app/auth.py`.
- Keep workflow validation in services, not route handlers.
- Keep data access behind `ShiftRepository`.
- Local development may use `InMemoryShiftRepository`; production must use DynamoDB conditional writes and transactions.
- Deploy FastAPI behind API Gateway + Lambda with Mangum when moving to AWS.

## DynamoDB Direction
- `UrgentShiftJob`: shift posting, location, time window, required workers, accepted workers, status.
- `ShiftBooking`: worker booking, lifecycle timestamps, payment state.
- `PaymentLedger`: future dedicated table for escrow holds, releases, refunds, failures, and disputes.
- Claiming a shift must be atomic: increment accepted workers only when the job is open and remaining slots exist, then create the booking.

## Shift Lifecycle
`accepted -> checked_in -> checked_out -> completed`

Dispute can happen before completion:
`accepted | checked_in | checked_out -> disputed`

Payment state for the happy path:
`held -> release_pending -> released`

## Setup Commands
```powershell
flutter pub get
flutter test
```

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
pytest
```

## Testing Checklist
- Worker can browse open urgent shifts.
- Worker can claim a shift with open slots.
- A filled shift cannot be over-claimed.
- Worker can check in only after acceptance.
- Worker can check out only after check-in.
- Employer can confirm only after checkout.
- Dispute sets booking and payment state to disputed.
- Role permissions block the wrong actor.
- Flutter mocked flow still works before AWS setup is present.

## Agent Rules
- Inspect context before editing.
- Explain the plan before big changes.
- Prefer simple working code first.
- Avoid unrelated refactors.
- Preserve existing patterns once the project develops them.
- After changes, tell the user exactly what to test.
- Do not add AI features until the core shift lifecycle is stable.
