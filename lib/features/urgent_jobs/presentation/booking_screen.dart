import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../application/urgent_shift_providers.dart';
import '../domain/shift_booking.dart';
import 'job_status_chip.dart';

class BookingScreen extends ConsumerWidget {
  const BookingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingProvider(bookingId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.jobDetails)),
      body: SafeArea(
        child: bookingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          data: (booking) {
            if (booking == null) {
              return Center(child: Text(l10n.text('noJobsFound')));
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
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${l10n.jobDetails} ${booking.bookingId}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            BookingStatusChip(status: booking.status),
          ],
        ),
        const SizedBox(height: 16),
        _TimelineRow(
          label: l10n.paymentUpdates,
          value: booking.paymentStatus.name,
          icon: Icons.account_balance_wallet_outlined,
        ),
        _TimelineRow(
          label: l10n.checkIn,
          value: _formatDate(booking.checkInAt),
          icon: Icons.login,
        ),
        _TimelineRow(
          label: l10n.checkOut,
          value: _formatDate(booking.checkOutAt),
          icon: Icons.logout,
        ),
        _TimelineRow(
          label: l10n.employer,
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
              label: Text(l10n.checkIn),
            ),
            FilledButton.icon(
              onPressed: booking.status == ShiftBookingStatus.checkedIn
                  ? () => repository.checkOut(booking.bookingId)
                  : null,
              icon: const Icon(Icons.logout),
              label: Text(l10n.checkOut),
            ),
            FilledButton.icon(
              onPressed: booking.status == ShiftBookingStatus.checkedOut
                  ? () => repository.confirm(booking.bookingId)
                  : null,
              icon: const Icon(Icons.verified_outlined),
              label: Text(l10n.confirm),
            ),
            OutlinedButton.icon(
              onPressed:
                  booking.status == ShiftBookingStatus.completed ||
                      booking.status == ShiftBookingStatus.disputed
                  ? null
                  : () => repository.dispute(booking.bookingId),
              icon: const Icon(Icons.report_problem_outlined),
              label: Text(l10n.error),
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
