import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/urgent_shift_providers.dart';
import '../domain/shift_booking.dart';
import 'job_status_chip.dart';

class BookingScreen extends ConsumerWidget {
  const BookingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Shift booking')),
      body: SafeArea(
        child: bookingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          data: (booking) {
            if (booking == null) {
              return const Center(child: Text('Booking not found.'));
            }
            return _BookingBody(booking: booking);
          },
        ),
      ),
    );
  }
}

class _BookingBody extends ConsumerWidget {
  const _BookingBody({required this.booking});

  final ShiftBooking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(urgentShiftRepositoryProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Booking ${booking.bookingId}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            BookingStatusChip(status: booking.status),
          ],
        ),
        const SizedBox(height: 16),
        _TimelineRow(
          label: 'Payment',
          value: booking.paymentStatus.name,
          icon: Icons.account_balance_wallet_outlined,
        ),
        _TimelineRow(
          label: 'Check-in',
          value: _formatDate(booking.checkInAt),
          icon: Icons.login,
        ),
        _TimelineRow(
          label: 'Check-out',
          value: _formatDate(booking.checkOutAt),
          icon: Icons.logout,
        ),
        _TimelineRow(
          label: 'Employer confirmation',
          value: _formatDate(booking.employerConfirmedAt),
          icon: Icons.verified_outlined,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: booking.status == ShiftBookingStatus.accepted
                  ? () => repository.checkIn(booking.bookingId)
                  : null,
              icon: const Icon(Icons.login),
              label: const Text('Check in'),
            ),
            FilledButton.icon(
              onPressed: booking.status == ShiftBookingStatus.checkedIn
                  ? () => repository.checkOut(booking.bookingId)
                  : null,
              icon: const Icon(Icons.logout),
              label: const Text('Check out'),
            ),
            FilledButton.icon(
              onPressed: booking.status == ShiftBookingStatus.checkedOut
                  ? () => repository.confirm(booking.bookingId)
                  : null,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Confirm'),
            ),
            OutlinedButton.icon(
              onPressed:
                  booking.status == ShiftBookingStatus.completed ||
                      booking.status == ShiftBookingStatus.disputed
                  ? null
                  : () => repository.dispute(booking.bookingId),
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Dispute'),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Pending';
    }
    return DateFormat('MMM d, HH:mm').format(value);
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(value),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
