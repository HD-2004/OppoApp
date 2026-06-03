# Auth Intro And Login Design

## Goal

Build a Flutter-first introduction screen and refreshed login screen for Ốp Pờ, using the bright teal F&B direction from the reference image.

## User Flow

Unauthenticated users land on `/intro`. The intro screen presents the brand, a F&B illustration, a short value proposition, three benefits, and a primary action. Tapping `Bắt đầu ngay` or `Đăng nhập` routes to `/login`. Existing auth routes for register, forgot password, confirmation, and reset remain available.

Authenticated users keep the current role-based redirects to candidate or employer dashboards.

## Visual Direction

Use a light warm background, teal brand color, large readable Vietnamese copy, rounded but restrained controls, and a custom Flutter illustration representing a cafe worker and candidate. The login screen shares the same palette and spacing so it feels like the next step from the intro.

## Implementation Boundaries

Add a new Flutter screen for introduction, refresh `LoginScreen` UI only, and update router tests. Keep Cognito/Riverpod sign-in behavior unchanged.
