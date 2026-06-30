# Job Recruitment Window Design

## Goal

Separate a job post's recruitment window from its work schedule so candidates can scan mobile job cards quickly while still seeing full shift details on the job detail screen.

## Business Rules

- A job post has a recruitment start date and recruitment end date.
- Dates are shown to users in Vietnamese format: `dd/MM/yyyy`.
- Dates should be stored as ISO date or datetime values for filtering and comparison.
- A job remains active through the full end date. For example, a post ending on `15/07/2026` stays visible and open for applications until the end of that day.
- Expired job posts are not deleted from the database.
- Expired job posts are hidden from normal candidate job lists.
- Expired job posts are retained for application history, analytics, conversations, audit, and future renewal flows.
- If a candidate opens an expired post from an old link or saved state, the app shows that the post has expired and disables applying.

## Data Model

Each job post should expose these fields from the backend:

```text
recruitmentStartDate: 2026-07-01
recruitmentEndDate: 2026-07-15
status: active | expired | archived
```

The candidate-facing job APIs should prefer returning only jobs that are currently recruitable:

```text
status = active
recruitmentStartDate <= today
recruitmentEndDate >= today
```

The Flutter app should still defensively hide or block expired jobs if stale data reaches the client.

## Candidate List Card

The mobile card should prioritize the recruitment date range and not show shift details. This keeps the list compact and easy to scan.

Display:

```text
Tuyển dụng: 01/07/2026 - 15/07/2026
```

If either date is missing, the app should fall back to a conservative label such as `Tuyển dụng: Không công khai` rather than showing misleading data.

## Job Detail Screen

The detail screen should show both the recruitment window and the work schedule.

Display:

```text
Thời gian tuyển dụng
01/07/2026 - 15/07/2026

Lịch làm việc
T2  T3  T4  T5
06:30 - 11:00

T5  T6  T7
08:00 - 11:30
```

The work schedule section should use the label `Lịch làm việc`.

If the backend provides grouped schedules, the app should render each day/time group as a separate readable row. If the backend only provides the legacy `shiftTime` string, the app can initially display that string in the detail screen while the backend contract is upgraded.

## Expired Post Behavior

- Candidate lists should not show expired posts.
- Job detail screens should show `Tin tuyển dụng đã hết hạn` for expired posts.
- Apply buttons should be disabled for expired posts.
- Saved jobs should not count expired posts as currently active job opportunities.

## Follow-Up Reminder

After this feature is completed, revisit date formatting across the whole app and standardize every user-facing date to the approved Vietnamese display format.
