# Candidate Age Gate Registration Design

## Goal

Block candidates under 18 from using the app as early as possible, while keeping Google sign-in available. Store every accepted candidate's date of birth in the user profile for future KYC and profile features.

## Business Rules

- The app is candidate-only, so the 18+ rule applies to every user.
- A candidate is eligible on the exact day they turn 18.
- For example, on 2026-06-29, a candidate born on 2008-06-29 is eligible and one born on 2008-06-30 is not.
- Invalid, empty, future, or under-18 birth dates are rejected.

## Email And Password Flow

- The registration form asks for date of birth in addition to full name, email, password, and confirm password.
- Date of birth is required before the submit button can be enabled.
- The form validates age before calling Cognito sign-up.
- Eligible candidates continue through the existing email confirmation flow.
- The accepted date of birth is carried in the registration request and saved to the candidate profile when the profile is created or updated.

## Google Flow

- Google sign-in remains available.
- After Google sign-in, the app fetches or creates the local profile as it does today.
- If the signed-in profile has no date of birth, router redirects to a dedicated candidate age verification screen.
- Eligible candidates save their date of birth to the profile and then enter `/candidate`.
- Under-18 candidates see a blocking message, are signed out, and return to auth.

## Architecture

- Add a small reusable age policy helper under auth domain or application code.
- Extend `RegisterRequest` and pending registration profile data with `dateOfBirth`.
- Update `AwsUserProfileRepository` so profile creation can include `dateOfBirth`.
- Add a `/candidate/age-verification` route and route guard before `/candidate`.
- Add a focused screen for Google users who need to provide date of birth.
- Keep unrelated profile screens unchanged except for shared validation where it is directly useful.

## Testing

- Unit-test age eligibility boundaries.
- Widget-test the registration form shows and requires date of birth.
- Widget-test under-18 registration validation blocks submission.
- Test profile creation payload includes `dateOfBirth`.
- Test router helper logic redirects authenticated users without date of birth to the age verification route.
