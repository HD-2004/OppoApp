import 'package:flutter/material.dart';

import '../domain/shift_booking.dart';
import '../domain/urgent_shift_job.dart';

class JobStatusChip extends StatelessWidget {
  const JobStatusChip({super.key, required this.status});

  final UrgentShiftStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      UrgentShiftStatus.draft => 'Draft',
      UrgentShiftStatus.open => 'Open',
      UrgentShiftStatus.filled => 'Filled',
      UrgentShiftStatus.inProgress => 'In progress',
      UrgentShiftStatus.completed => 'Completed',
      UrgentShiftStatus.cancelled => 'Cancelled',
    };
    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }
}

class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({super.key, required this.status});

  final ShiftBookingStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ShiftBookingStatus.accepted => 'Accepted',
      ShiftBookingStatus.checkedIn => 'Checked in',
      ShiftBookingStatus.checkedOut => 'Checked out',
      ShiftBookingStatus.completed => 'Completed',
      ShiftBookingStatus.cancelled => 'Cancelled',
      ShiftBookingStatus.disputed => 'Disputed',
    };
    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }
}
