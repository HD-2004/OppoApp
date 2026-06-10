import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/aws_urgent_shift_repository.dart';
import '../data/urgent_shift_repository.dart';
import '../domain/shift_booking.dart';
import '../domain/urgent_shift_job.dart';

final urgentShiftRepositoryProvider = Provider<UrgentShiftRepository>((ref) {
  final repository = AwsUrgentShiftRepository();
  ref.onDispose(repository.close);
  return repository;
});

final openUrgentJobsProvider = StreamProvider<List<UrgentShiftJob>>((ref) {
  return ref.watch(urgentShiftRepositoryProvider).watchOpenJobs();
});

final employerUrgentJobsProvider = StreamProvider<List<UrgentShiftJob>>((ref) {
  final employerId = ref
      .watch(authControllerProvider)
      .asData
      ?.value
      .user
      ?.userId;
  if (employerId == null || employerId.isEmpty) {
    return Stream.value(const []);
  }
  return ref.watch(urgentShiftRepositoryProvider).watchEmployerJobs(employerId);
});

final bookingProvider = StreamProvider.family<ShiftBooking?, String>((
  ref,
  bookingId,
) {
  return ref.watch(urgentShiftRepositoryProvider).watchBooking(bookingId);
});
