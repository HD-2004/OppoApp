import '../domain/shift_booking.dart';
import '../domain/urgent_shift_job.dart';

abstract interface class UrgentShiftRepository {
  Stream<List<UrgentShiftJob>> watchOpenJobs();
  Stream<List<UrgentShiftJob>> watchEmployerJobs(String employerId);
  Stream<ShiftBooking?> watchBooking(String bookingId);
  Future<ShiftBooking> claimShift({
    required String jobId,
    required String workerId,
  });
  Future<ShiftBooking> checkIn(String bookingId);
  Future<ShiftBooking> checkOut(String bookingId);
  Future<ShiftBooking> confirm(String bookingId);
  Future<ShiftBooking> dispute(String bookingId);
}
