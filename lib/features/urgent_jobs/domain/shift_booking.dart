enum ShiftBookingStatus {
  accepted,
  checkedIn,
  checkedOut,
  completed,
  cancelled,
  disputed,
}

enum PaymentStatus {
  holdPending,
  held,
  releasePending,
  released,
  refundPending,
  refunded,
  failed,
  disputed,
}

class ShiftBooking {
  const ShiftBooking({
    required this.bookingId,
    required this.jobId,
    required this.workerId,
    required this.status,
    required this.paymentStatus,
    this.checkInAt,
    this.checkOutAt,
    this.employerConfirmedAt,
  });

  final String bookingId;
  final String jobId;
  final String workerId;
  final ShiftBookingStatus status;
  final PaymentStatus paymentStatus;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final DateTime? employerConfirmedAt;

  ShiftBooking copyWith({
    ShiftBookingStatus? status,
    PaymentStatus? paymentStatus,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    DateTime? employerConfirmedAt,
  }) {
    return ShiftBooking(
      bookingId: bookingId,
      jobId: jobId,
      workerId: workerId,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      checkInAt: checkInAt ?? this.checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      employerConfirmedAt: employerConfirmedAt ?? this.employerConfirmedAt,
    );
  }
}
