import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/auth_state.dart';
import '../features/auth/presentation/confirm_signup_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/introduction_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/missing_role_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/candidate/presentation/kyc_verification_screen.dart';
import '../features/candidate/presentation/update_profile_screen.dart';
import '../features/candidate/presentation/user_dashboard_screen.dart';
import '../features/employer/presentation/employer_home_screen.dart';
import '../features/employer/presentation/employer_pending_review_screen.dart';
import '../features/employer/presentation/employer_rejected_screen.dart';
import '../features/home/home_screen.dart';
import '../features/urgent_jobs/presentation/booking_screen.dart';
import '../features/urgent_jobs/presentation/employer_dashboard_screen.dart';
import '../features/urgent_jobs/presentation/shift_detail_screen.dart';
import '../shared/domain/app_role.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authControllerProvider);

  final router = GoRouter(
    initialLocation: '/intro',
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      if (authState.isLoading) {
        return null;
      }

      final value =
          authState.asData?.value ?? const AuthState.unauthenticated();
      final location = state.matchedLocation;
      final isAuthRoute =
          location == '/intro' ||
          location == '/login' ||
          location == '/register' ||
          location == '/confirm-signup' ||
          location == '/forgot-password' ||
          location == '/reset-password';

      if (value.status == AuthStatus.unauthenticated) {
        return isAuthRoute ? null : '/intro';
      }

      if (value.status == AuthStatus.unconfirmed) {
        final email = value.pendingEmail;
        final query = email == null
            ? ''
            : '?email=${Uri.encodeComponent(email)}';
        return location == '/confirm-signup' ? null : '/confirm-signup$query';
      }

      if (value.status == AuthStatus.missingRole) {
        return location == '/missing-role' ? null : '/missing-role';
      }

      final user = value.user;
      if (user == null) {
        return '/intro';
      }

      if (user.role == AppRole.employer) {
        if (user.isEmployerApproved) {
          if (isAuthRoute ||
              location == '/' ||
              location == '/missing-role' ||
              location == '/employer/pending-review' ||
              location == '/employer/rejected') {
            return '/employer';
          }
          return null;
        }
        if (user.isEmployerRejected) {
          return location == '/employer/rejected' ? null : '/employer/rejected';
        }
        return location == '/employer/pending-review'
            ? null
            : '/employer/pending-review';
      }

      if (user.role == AppRole.candidate) {
        if (isAuthRoute ||
            location == '/' ||
            location == '/missing-role' ||
            location == '/candidate/kyc' ||
            location == '/candidate/update-profile') {
          return '/candidate';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/intro',
        builder: (context, state) => const IntroductionScreen(),
      ),
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
      GoRoute(
        path: '/missing-role',
        builder: (context, state) => const MissingRoleScreen(),
      ),
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
      GoRoute(
        path: '/employer',
        builder: (context, state) => const EmployerHomeScreen(),
      ),
      GoRoute(
        path: '/employer/pending-review',
        builder: (context, state) => const EmployerPendingReviewScreen(),
      ),
      GoRoute(
        path: '/employer/rejected',
        builder: (context, state) => const EmployerRejectedScreen(),
      ),
      GoRoute(
        path: '/employer-demo',
        builder: (context, state) => const EmployerDashboardScreen(),
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
        previous?.value?.user?.role != next.value?.user?.role ||
        previous?.value?.user?.employerStatus !=
            next.value?.user?.employerStatus) {
      router.refresh();
    }
  });

  return router;
});
