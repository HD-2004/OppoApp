import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_urgent_shift_repository.dart';
import '../data/urgent_shift_repository.dart';
import '../domain/shift_booking.dart';
import '../domain/urgent_shift_job.dart';

// App-only urgent shift workflow for screens that still need a local stream.
// Candidate home uses activeQuickJobsProvider for backend-backed quick jobs.
final urgentShiftRepositoryProvider = Provider<UrgentShiftRepository>((ref) {
  return MockUrgentShiftRepository();
});

final openUrgentJobsProvider = StreamProvider<List<UrgentShiftJob>>((ref) {
  return ref.watch(urgentShiftRepositoryProvider).watchOpenJobs();
});

final employerUrgentJobsProvider = StreamProvider<List<UrgentShiftJob>>((ref) {
  return ref
      .watch(urgentShiftRepositoryProvider)
      .watchEmployerJobs('employer-demo');
});

final bookingProvider = StreamProvider.family<ShiftBooking?, String>((
  ref,
  bookingId,
) {
  return ref.watch(urgentShiftRepositoryProvider).watchBooking(bookingId);
});
