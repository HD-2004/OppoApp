import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/urgent_jobs/presentation/booking_screen.dart';
import '../features/urgent_jobs/presentation/employer_dashboard_screen.dart';
import '../features/urgent_jobs/presentation/shift_detail_screen.dart';
import '../features/urgent_jobs/presentation/worker_marketplace_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/worker',
      builder: (context, state) => const WorkerMarketplaceScreen(),
    ),
    GoRoute(
      path: '/employer',
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
