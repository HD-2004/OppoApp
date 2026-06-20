import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';

import '../../domain/job_post.dart';

/// Controls how a [JobPostCard] sizes and clamps its content depending on
/// where it is rendered. `grid` is the compact two-column masonry layout,
/// while `list`/`feed` are the full-width vertical layouts.
enum JobCardLayout { grid, list, feed }

class JobPostCard extends StatelessWidget {
  const JobPostCard({
    super.key,
    required this.job,
    required this.onDetailsPressed,
    required this.onApplyPressed,
    this.layout = JobCardLayout.list,
    this.distance,
    this.isApplying = false,
    this.isSaved = false,
    this.onSavePressed,
  });

  final JobPost job;
  final JobCardLayout layout;
  final VoidCallback onDetailsPressed;
  final VoidCallback? onApplyPressed;
  final double? distance;
  final bool isApplying;
  final bool isSaved;
  final VoidCallback? onSavePressed;

  bool get _isGrid => layout == JobCardLayout.grid;

  String _postedTimeLabel(DateTime postedAt) {
    if (postedAt.millisecondsSinceEpoch == 0) {
      return '';
    }

    final diff = DateTime.now().difference(postedAt);
    if (diff.isNegative || diff.inMinutes < 1) {
      return 'Vừa đăng';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    }
    return '${diff.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final companyName = _companyName(job);
    final postedTime = _postedTimeLabel(job.postedAt);
    final requirements = _requirements(job);
    final shiftTime = _shiftTime(job);
    final location = _location(job, distance);
    final salary = _salary(job);

    final isGrid = _isGrid;
    final padding = isGrid ? 14.0 : 16.0;
    final avatarSize = isGrid ? 40.0 : 44.0;
    final headerSpacing = isGrid ? 12.0 : 16.0;
    final infoSpacing = isGrid ? 12.0 : 14.0;
    final buttonSpacing = isGrid ? 14.0 : 18.0;
    final buttonHeight = isGrid ? 44.0 : 50.0;
    // Grid cards live in narrow columns, so clamp long values to keep the
    // masonry tidy. List/feed cards have full width and can show more.
    final infoValueMaxLines = isGrid ? 2 : 3;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      elevation: 0,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: InkWell(
        onTap: onDetailsPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CompanyMark(companyName: companyName, size: avatarSize),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (postedTime.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            postedTime,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SaveJobButton(isSaved: isSaved, onPressed: onSavePressed),
                ],
              ),
              SizedBox(height: headerSpacing),
              Text(
                job.title.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              SizedBox(height: infoSpacing),
              _JobInfoColumn(
                valueMaxLines: infoValueMaxLines,
                rows: [
                  if (requirements.isNotEmpty)
                    _JobInfoRowData(
                      label: 'Yêu cầu',
                      value: requirements,
                      icon: Icons.fact_check_outlined,
                    ),
                  if (location.isNotEmpty)
                    _JobInfoRowData(
                      label: 'Địa chỉ',
                      value: location,
                      icon: Icons.location_on_outlined,
                    ),
                  if (shiftTime.isNotEmpty)
                    _JobInfoRowData(
                      label: 'Thời gian',
                      value: shiftTime,
                      icon: Icons.schedule_rounded,
                    ),
                  if (salary.isNotEmpty)
                    _JobInfoRowData(
                      label: 'Lương',
                      value: salary,
                      icon: Icons.payments_outlined,
                      emphasized: true,
                    ),
                  _JobInfoRowData(
                    label: 'Hình thức',
                    value: job.jobType.label,
                    icon: Icons.work_outline_rounded,
                  ),
                ],
              ),
              SizedBox(height: buttonSpacing),
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: FilledButton(
                  onPressed: isApplying ? null : onApplyPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: theme.colorScheme.outlineVariant,
                    disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isApplying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Ứng tuyển ngay',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveJobButton extends StatelessWidget {
  const _SaveJobButton({required this.isSaved, this.onPressed});

  final bool isSaved;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSaved
        ? AppColors.primary
        : theme.colorScheme.onSurfaceVariant;

    return IconButton(
      tooltip: isSaved ? 'Bỏ lưu công việc' : 'Lưu công việc',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: isSaved
            ? AppColors.primary.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        foregroundColor: color,
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
      ),
      icon: Icon(
        isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        size: 22,
      ),
    );
  }
}

class _CompanyMark extends StatelessWidget {
  const _CompanyMark({required this.companyName, this.size = 44});

  final String companyName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = companyName.characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        initial,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _JobInfoColumn extends StatelessWidget {
  const _JobInfoColumn({required this.rows, this.valueMaxLines = 3});

  final List<_JobInfoRowData> rows;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          _JobInfoRow(data: rows[index], valueMaxLines: valueMaxLines),
          if (index < rows.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _JobInfoRow extends StatelessWidget {
  const _JobInfoRow({required this.data, this.valueMaxLines = 3});

  final _JobInfoRowData data;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          data.icon,
          size: 18,
          color: data.emphasized
              ? AppColors.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.value,
                maxLines: valueMaxLines,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: data.emphasized
                      ? AppColors.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: data.emphasized
                      ? FontWeight.w800
                      : FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JobInfoRowData {
  const _JobInfoRowData({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool emphasized;
}

String _companyName(JobPost job) {
  final companyName = job.companyName?.trim();
  if (companyName != null && companyName.isNotEmpty) {
    return companyName;
  }

  final employerName = job.employerName.trim();
  if (employerName.isNotEmpty) {
    return employerName;
  }

  return 'Nhà tuyển dụng';
}

String _location(JobPost job, double? distance) {
  final location = job.location.trim();
  if (location.isEmpty) {
    return '';
  }
  if (distance == null) {
    return location;
  }
  return '$location · cách ${distance.toStringAsFixed(1)} km';
}

String _requirements(JobPost job) {
  return job.requirements?.trim() ?? '';
}

String _shiftTime(JobPost job) {
  final startTime = job.startTime?.trim();
  final endTime = job.endTime?.trim();
  if (startTime != null &&
      startTime.isNotEmpty &&
      endTime != null &&
      endTime.isNotEmpty) {
    return '$startTime - $endTime';
  }

  final shiftTime = job.shiftTime.trim();
  if (shiftTime.isNotEmpty) {
    return shiftTime;
  }

  return '';
}

String _salary(JobPost job) {
  if (job.totalSalary != null && job.totalSalary! > 0) {
    final candidateIncome = (job.totalSalary! * 0.85).round();
    return '${_formatMoney(candidateIncome)} VND / ca';
  }

  final salary = job.salary.trim();
  if (salary.isNotEmpty) {
    return salary;
  }

  return '';
}

String _formatMoney(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final remaining = raw.length - i;
    buffer.write(raw[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}
