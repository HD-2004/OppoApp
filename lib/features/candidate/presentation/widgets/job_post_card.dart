import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/job_post.dart';
import '../user_job_detail_screen.dart';

class JobPostCard extends StatefulWidget {
  const JobPostCard({super.key, required this.job});

  final JobPost job;

  @override
  State<JobPostCard> createState() => _JobPostCardState();
}

class _JobPostCardState extends State<JobPostCard> {
  late bool _isSaved = widget.job.isSaved;

  String get _postedTimeLabel {
    final diff = DateTime.now().difference(widget.job.postedAt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes.clamp(1, 59)} phút trước';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    }
    return '${diff.inDays} ngày trước';
  }

  void _toggleSave() {
    setState(() {
      _isSaved = !_isSaved;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          ).text(_isSaved ? 'jobSaved' : 'jobUnsaved'),
        ),
      ),
    );
  }

  void _showApplyPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).text('searchWillBeBuilt')),
      ),
    );
  }

  void _openDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserJobDetailScreen(job: widget.job)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    widget.job.employerName.characters.first,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.job.employerName,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _postedTimeLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_jobTypeLabel(l10n, widget.job.jobType)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.job.title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: widget.job.location,
            ),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.payments_outlined, text: widget.job.salary),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.schedule_outlined, text: widget.job.shiftTime),
            const SizedBox(height: 12),
            Text(widget.job.description, style: textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in widget.job.tags)
                  Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _toggleSave,
                  icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
                  label: Text(_isSaved ? l10n.text('savedJob') : l10n.saveJob),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _openDetails,
                  child: Text(l10n.text('details')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _showApplyPlaceholder,
                  child: Text(l10n.text('apply')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _jobTypeLabel(AppLocalizations l10n, JobPostType type) {
  return switch (type) {
    JobPostType.urgent => l10n.text('urgentShift'),
    JobPostType.partTime => l10n.partTime,
  };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
