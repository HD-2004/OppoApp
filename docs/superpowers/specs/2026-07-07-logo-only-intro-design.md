# Logo-Only Intro Design

## Goal

Redesign the first app introduction experience so it is logo-first and sized correctly for mobile. The intro should establish the Ốp Pờ brand before the user enters authentication, without showing product dashboards, job cards, sample users, fake metrics, posters, or onboarding illustrations.

## Scope

This design covers only:

- `SplashScreen`
- `IntroScreen`
- Entry actions from intro to login

This design does not cover candidate home, jobs, profile, wallet, messages, employer flows, or any authenticated app surface.

## User Flow

The app opens at `/splash`. The splash screen shows only the Ốp Pờ logo, centered, while the app checks whether the intro has already been seen.

If the intro has not been seen, the app routes to `/intro`. The intro screen shows a centered logo tile with two actions:

- `Bắt đầu ngay`
- `Đăng nhập`

Both actions keep the existing behavior: mark the intro as seen and route to `/login`.

If the intro has already been seen, the app keeps the existing redirect to `/login`.

## Visual Direction

The intro uses the Ốp Pờ logo as the only content focus. The page should feel calm, polished, and app-sized rather than like a website hero.

Use:

- A soft ice-blue to white background
- Subtle logo-inspired circular/bubble shapes in the background
- A centered white logo tile with soft brand-tinted shadow
- Deep navy primary button
- White outlined secondary button
- Rounded pill actions

Do not use:

- F&B photos or illustrations
- Website posters
- Job cards
- Sample workers or employers
- Sample balances, metrics, locations, market stats, or any mock data
- Bottom navigation or authenticated app UI

## Responsive Sizing

Use Flutter logical pixels and responsive clamps.

- Page horizontal padding: `24dp`
- Content max width: `360dp`
- Logo tile: `46%` of screen width, clamped between `160dp` and `196dp`
- Logo image inside tile: `70-74%` of the tile size, max `140dp`
- Primary and secondary buttons: max `280dp` wide
- Button height: `56dp`
- Gap between buttons: `14dp`
- Gap between logo tile and primary button: `24-32dp`

For larger screens, keep the centered `360dp` column and let the background breathe. Do not stretch the logo tile or buttons.

For splash, use only the logo mark centered at about `132-160dp`, clamped for small devices.

## Data Boundary

No fake data or mock data should be introduced. This intro is a static brand and navigation surface only. It may use real static brand assets and fixed UI copy, but it must not invent jobs, users, employers, salaries, counts, balances, ratings, notifications, or other product data.

## Implementation Boundaries

Use the existing intro routing and persistence behavior from `introControllerProvider` and `introRepositoryProvider`.

Replace the old intro illustration layout with a logo-only layout. Register and use an existing Ốp Pờ logo asset from `img/` rather than creating a new fake brand asset.

Keep authentication, Amplify, Riverpod, and route redirect behavior unchanged.

## Testing

Update widget tests that cover the intro flow so they assert the new logo-only content and actions. Existing navigation behavior should remain covered: first-time users see `/intro`, and continuing from intro routes to `/login`.
