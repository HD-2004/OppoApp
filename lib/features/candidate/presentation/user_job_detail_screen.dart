import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/job_post.dart';

class UserJobDetailScreen extends StatelessWidget {
  const UserJobDetailScreen({
    super.key,
    required this.job,
    required this.onApplyPressed,
  });

  final JobPost job;
  final VoidCallback onApplyPressed;

  String _formatDateString(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.jobDetails),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Job Title & Company Name
                    Text(
                      job.title,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      job.employerName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Info Card (matches the web apply-info-card)
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          _DetailRow(label: 'Địa điểm', value: job.location),
                          _DetailRow(
                            label: 'Mức lương',
                            value: job.salary,
                            isSalary: true,
                          ),
                          _DetailRow(
                            label: 'Loại hình',
                            value: job.jobType == JobPostType.urgent
                                ? 'Ca gấp'
                                : job.jobType == JobPostType.partTime
                                ? 'Bán thời gian'
                                : 'Toàn thời gian',
                          ),
                          _DetailRow(
                            label: 'Ngày đăng',
                            value: _formatDateString(job.postedAt),
                          ),
                          if (job.isQuickJob &&
                              job.workDate != null &&
                              job.workDate!.isNotEmpty)
                            _DetailRow(label: 'Ngày làm', value: job.workDate!),
                          if (job.shiftTime.isNotEmpty)
                            _DetailRow(
                              label: 'Thời gian',
                              value: job.shiftTime,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Job Description
                    if (job.description.isNotEmpty) ...[
                      _SectionHeader(title: 'MÔ TẢ CÔNG VIỆC'),
                      const SizedBox(height: 8),
                      Text(
                        job.description,
                        style: textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Responsibilities
                    if (job.responsibilities != null &&
                        job.responsibilities!.isNotEmpty) ...[
                      _SectionHeader(title: 'TRÁCH NHIỆM'),
                      const SizedBox(height: 8),
                      Text(
                        job.responsibilities!,
                        style: textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Requirements
                    if (job.requirements != null &&
                        job.requirements!.isNotEmpty) ...[
                      _SectionHeader(title: 'YÊU CẦU'),
                      const SizedBox(height: 8),
                      Text(
                        job.requirements!,
                        style: textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Benefits
                    if (job.benefits != null && job.benefits!.isNotEmpty) ...[
                      _SectionHeader(title: 'CHẾ ĐỘ PHÚC LỢI'),
                      const SizedBox(height: 8),
                      Text(
                        job.benefits!,
                        style: textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),

            // Sticky Bottom Bar with Apply button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApplyPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Ứng tuyển ngay',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isSalary = false,
  });

  final String label;
  final String value;
  final bool isSalary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSalary
                    ? const Color(0xFF2E7D32)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 14,
        color: const Color(0xFF1E40AF),
        letterSpacing: 0.5,
      ),
    );
  }
}
