# Ốp Pờ

A Flutter + FastAPI + AWS Amplify scaffold for a temporary job recruitment app. V1 focuses on urgent shift-based jobs before adding part-time recruitment, agreements, CV processing, and AI matching.

## Mobile

```powershell
flutter pub get
flutter test
flutter run
```

The current Flutter app uses a mocked urgent-shift repository so the main worker and employer flows can be exercised before AWS resources are connected.

## Backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
pytest
```

Local auth uses request headers:

- `x-user-id`
- `x-role`: `worker`, `employer`, or `admin`

Production should replace the header shim with Cognito JWT verification.

## Architecture Notes

- Flutter reads real-time state through Amplify/AppSync when AWS is configured.
- FastAPI owns high-risk commands like claim, check-in, check-out, confirm, and dispute.
- DynamoDB production writes must use conditional updates and transactions for shift claims.
- See `AI-agent.md` for implementation rules and project conventions.
