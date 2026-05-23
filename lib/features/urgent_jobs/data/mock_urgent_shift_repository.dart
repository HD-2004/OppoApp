import 'dart:async';

import '../domain/shift_booking.dart';
import '../domain/urgent_shift_job.dart';
import 'urgent_shift_repository.dart';

class MockUrgentShiftRepository implements UrgentShiftRepository {
  MockUrgentShiftRepository() {
    _jobs = [
      UrgentShiftJob(
        jobId: 'shift-001',
        employerId: 'employer-demo',
        title: 'Warehouse packing shift',
        category: 'Logistics',
        address: 'District 7, Ho Chi Minh City',
        latitude: 10.738,
        longitude: 106.721,
        startTime: DateTime.now().add(const Duration(hours: 3)),
        endTime: DateTime.now().add(const Duration(hours: 9)),
        payAmount: 420000,
        currency: 'VND',
        requiredWorkers: 4,
        acceptedWorkers: 1,
        status: UrgentShiftStatus.open,
      ),
      UrgentShiftJob(
        jobId: 'shift-002',
        employerId: 'employer-demo',
        title: 'Cafe service evening shift',
        category: 'Food service',
        address: 'District 1, Ho Chi Minh City',
        latitude: 10.776,
        longitude: 106.700,
        startTime: DateTime.now().add(const Duration(hours: 5)),
        endTime: DateTime.now().add(const Duration(hours: 10)),
        payAmount: 320000,
        currency: 'VND',
        requiredWorkers: 2,
        acceptedWorkers: 0,
        status: UrgentShiftStatus.open,
      ),
    ];
    _emit();
  }

  late List<UrgentShiftJob> _jobs;
  final Map<String, ShiftBooking> _bookings = {};
  final _jobsController = StreamController<List<UrgentShiftJob>>.broadcast();
  final _bookingController = StreamController<ShiftBooking?>.broadcast();

  @override
  Stream<List<UrgentShiftJob>> watchOpenJobs() async* {
    yield _jobs.where((job) => job.status == UrgentShiftStatus.open).toList();
    yield* _jobsController.stream.map(
      (jobs) =>
          jobs.where((job) => job.status == UrgentShiftStatus.open).toList(),
    );
  }

  @override
  Stream<List<UrgentShiftJob>> watchEmployerJobs(String employerId) async* {
    yield _jobs.where((job) => job.employerId == employerId).toList();
    yield* _jobsController.stream.map(
      (jobs) => jobs.where((job) => job.employerId == employerId).toList(),
    );
  }

  @override
  Stream<ShiftBooking?> watchBooking(String bookingId) async* {
    yield _bookings[bookingId];
    yield* _bookingController.stream.where(
      (booking) => booking == null || booking.bookingId == bookingId,
    );
  }

  @override
  Future<ShiftBooking> claimShift({
    required String jobId,
    required String workerId,
  }) async {
    final index = _jobs.indexWhere((job) => job.jobId == jobId);
    if (index == -1) {
      throw StateError('Shift not found.');
    }

    final job = _jobs[index];
    if (job.status != UrgentShiftStatus.open || !job.hasOpenSlots) {
      throw StateError('Shift is no longer available.');
    }

    final acceptedWorkers = job.acceptedWorkers + 1;
    _jobs[index] = job.copyWith(
      acceptedWorkers: acceptedWorkers,
      status: acceptedWorkers == job.requiredWorkers
          ? UrgentShiftStatus.filled
          : UrgentShiftStatus.open,
    );

    final booking = ShiftBooking(
      bookingId: 'booking-${DateTime.now().microsecondsSinceEpoch}',
      jobId: jobId,
      workerId: workerId,
      status: ShiftBookingStatus.accepted,
      paymentStatus: PaymentStatus.held,
    );
    _bookings[booking.bookingId] = booking;
    _emit(booking);
    return booking;
  }

  @override
  Future<ShiftBooking> checkIn(String bookingId) async {
    return _transition(
      bookingId,
      expected: ShiftBookingStatus.accepted,
      next: (booking) => booking.copyWith(
        status: ShiftBookingStatus.checkedIn,
        checkInAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<ShiftBooking> checkOut(String bookingId) async {
    return _transition(
      bookingId,
      expected: ShiftBookingStatus.checkedIn,
      next: (booking) => booking.copyWith(
        status: ShiftBookingStatus.checkedOut,
        paymentStatus: PaymentStatus.releasePending,
        checkOutAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<ShiftBooking> confirm(String bookingId) async {
    return _transition(
      bookingId,
      expected: ShiftBookingStatus.checkedOut,
      next: (booking) => booking.copyWith(
        status: ShiftBookingStatus.completed,
        paymentStatus: PaymentStatus.released,
        employerConfirmedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<ShiftBooking> dispute(String bookingId) async {
    final booking = _bookings[bookingId];
    if (booking == null) {
      throw StateError('Booking not found.');
    }
    final disputed = booking.copyWith(
      status: ShiftBookingStatus.disputed,
      paymentStatus: PaymentStatus.disputed,
    );
    _bookings[bookingId] = disputed;
    _emit(disputed);
    return disputed;
  }

  Future<ShiftBooking> _transition(
    String bookingId, {
    required ShiftBookingStatus expected,
    required ShiftBooking Function(ShiftBooking booking) next,
  }) async {
    final booking = _bookings[bookingId];
    if (booking == null) {
      throw StateError('Booking not found.');
    }
    if (booking.status != expected) {
      throw StateError('Invalid booking state: ${booking.status.name}.');
    }
    final updated = next(booking);
    _bookings[bookingId] = updated;
    _emit(updated);
    return updated;
  }

  void _emit([ShiftBooking? booking]) {
    _jobsController.add(List.unmodifiable(_jobs));
    _bookingController.add(booking);
  }
}
