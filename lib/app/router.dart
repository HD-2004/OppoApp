import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/auth_state.dart';
import '../features/auth/presentation/confirm_signup_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/candidate/presentation/kyc_verification_screen.dart';
import '../features/candidate/presentation/update_profile_screen.dart';
import '../features/candidate/presentation/user_dashboard_screen.dart';
import '../features/home/home_screen.dart';
import '../features/intro/presentation/intro_screen.dart';
import '../features/intro/presentation/splash_screen.dart';
import '../features/urgent_jobs/presentation/booking_screen.dart';
import '../features/urgent_jobs/presentation/shift_detail_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      if (authState.isLoading) {
        return null;
      }

      final value =
          authState.asData?.value ?? const AuthState.unauthenticated();
      final location = state.matchedLocation;
      final isAuthRoute =
          location == '/splash' ||
          location == '/intro' ||
          location == '/login' ||
          location == '/register' ||
          location == '/confirm-signup' ||
          location == '/otp-verification' ||
          location == '/forgot-password' ||
          location == '/reset-password';

      if (value.status == AuthStatus.unauthenticated) {
        return isAuthRoute ? null : '/login';
      }

      if (value.status == AuthStatus.unconfirmed) {
        final email = value.pendingEmail;
        final query = email == null
            ? ''
            : '?email=${Uri.encodeComponent(email)}';
        return location == '/confirm-signup' ? null : '/confirm-signup$query';
      }

      final user = value.user;
      if (user == null) {
        return '/login';
      }

      if (isAuthRoute ||
          location == '/' ||
          location == '/missing-role' ||
          location.startsWith('/employer') ||
          location == '/candidate/kyc' ||
          location == '/candidate/update-profile') {
        return '/candidate';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/intro', builder: (context, state) => const IntroScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/confirm-signup',
        builder: (context, state) {
          return ConfirmSignUpScreen(email: state.uri.queryParameters['email']);
        },
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (context, state) {
          return ConfirmSignUpScreen(email: state.uri.queryParameters['email']);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) {
          return ForgotPasswordScreen(
            email: state.uri.queryParameters['email'],
          );
        },
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          return ResetPasswordScreen(email: state.uri.queryParameters['email']);
        },
      ),
      GoRoute(path: '/missing-role', redirect: (context, state) => '/candidate'),
      GoRoute(
        path: '/candidate',
        builder: (context, state) => const UserDashboardScreen(),
      ),
      GoRoute(
        path: '/user-dashboard',
        redirect: (context, state) => '/candidate',
      ),
      GoRoute(
        path: '/candidate/kyc',
        builder: (context, state) => const KycVerificationScreen(),
      ),
      GoRoute(
        path: '/candidate/update-profile',
        builder: (context, state) => const UpdateProfileScreen(),
      ),
      GoRoute(path: '/worker', redirect: (context, state) => '/candidate'),
      GoRoute(path: '/employer', redirect: (context, state) => '/candidate'),
      GoRoute(
        path: '/employer/packages',
        redirect: (context, state) => '/candidate',
      ),
      GoRoute(
        path: '/employer/pending-review',
        redirect: (context, state) => '/candidate',
      ),
      GoRoute(
        path: '/employer/rejected',
        redirect: (context, state) => '/candidate',
      ),
      GoRoute(
        path: '/employer-demo',
        redirect: (context, state) => '/candidate',
      ),
      GoRoute(
        path: '/jobs/:jobId',
        builder: (context, state) {
          return ShiftDetailScreen(jobId: state.pathParameters['jobId']!);
        },
      ),
      GoRoute(
        path: '/bookings/:bookingId',
        builder: (context, state) {
          return BookingScreen(bookingId: state.pathParameters['bookingId']!);
        },
      ),
    ],
  );

  ref.listen<AsyncValue<AuthState>>(authControllerProvider, (previous, next) {
    if (previous?.isLoading != next.isLoading ||
        previous?.value?.status != next.value?.status ||
        previous?.value?.user?.role != next.value?.user?.role) {
      router.refresh();
    }
  });

  return router;
});
