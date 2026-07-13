import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/formatters/app_date_formatter.dart';
import 'package:oppo_temp_jobs/shared/presentation/widgets/network_asset_image.dart';

import '../../../candidate/domain/job_post.dart';
import '../../../candidate/domain/job_work_schedule.dart';

/// Compact recruitment card optimized for mobile job discovery.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.onTap});

  final JobPost job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUrgent = job.jobType == JobPostType.urgent || job.isQuickJob;
    final company = job.companyName ?? job.employerName;
    final salary = job.salary.isNotEmpty ? job.salary : 'Thỏa thuận';
    final workDays = displayWorkShiftDays(job);
    final shiftTime = _resolveShiftTime();
    final location = job.location;
    final deadline = _deadlineLabel(job.recruitmentEndDate);
    final tags = _visibleTags(job);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CompanyLogo(
                  logoUrl: job.employerAvatarUrl,
                  companyName: company,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title.trim(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F2937),
                          height: 1.18,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _IconText(
                        icon: Icons.business_outlined,
                        text: company,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 10,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (location.isNotEmpty)
                            _IconText(
                              icon: Icons.location_on_outlined,
                              text: location,
                            ),
                          _IconText(
                            icon: Icons.work_outline_rounded,
                            text: _employmentTypeLabel(job.jobType),
                          ),
                          if (job.views > 0)
                            _IconText(
                              icon: Icons.visibility_outlined,
                              text: '${job.views} lượt xem',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(isUrgent: isUrgent),
              ],
            ),

            if (tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final tag in tags) _TagChip(label: tag)],
              ),
            ],

            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                'Thu nhập: $salary',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),

            if (workDays.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailLine(
                icon: Icons.event_available_outlined,
                text: 'Ngày làm: $workDays',
              ),
            ],
            if (shiftTime.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailLine(
                icon: Icons.access_time_rounded,
                text: 'Thời gian: $shiftTime',
              ),
            ],
            if (deadline.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailLine(
                icon: Icons.calendar_today_outlined,
                text: 'Hạn nộp: $deadline',
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                'Vị trí này có thể phù hợp với bạn',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveShiftTime() {
    // Quick job: startTime - endTime (từ backend field)
    if (job.isQuickJob) {
      if (job.startTime != null &&
          job.endTime != null &&
          job.startTime!.isNotEmpty &&
          job.endTime!.isNotEmpty) {
        return '${job.startTime} - ${job.endTime}';
      }
      if (job.workDate != null && job.workDate!.isNotEmpty) {
        return AppDateFormatter.formatVietnameseDateString(
          job.workDate,
          fallback: job.workDate!.trim(),
        );
      }
    }
    return displayWorkShiftTime(job);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isUrgent});

  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final color = isUrgent ? const Color(0xFFF97316) : const Color(0xFF2454C6);
    final background = isUrgent
        ? const Color(0xFFFFEDD5)
        : const Color(0xFFEFF6FF);
    final border = isUrgent ? const Color(0xFFFED7AA) : const Color(0xFFAEC5FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 7),
          Text(
            isUrgent ? 'Tuyển gấp' : 'Tiêu chuẩn',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({this.logoUrl, required this.companyName});

  final String? logoUrl;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    final borderRadius = BorderRadius.circular(18);
    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0xFFE1E7F0), width: 2),
      ),
      child: url != null && url.isNotEmpty
          ? NetworkAssetImage(
              url: url,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.circular(14),
              semanticLabel: 'Logo $companyName',
              placeholder: const _LogoFallback(),
            )
          : const _LogoFallback(),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.business_rounded,
      size: 16,
      color: Color(0xFFD1D5DB),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text, this.maxLines = 1});

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE6F2)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1F2937),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

String _employmentTypeLabel(JobPostType type) {
  return switch (type) {
    JobPostType.urgent => 'Tuyển gấp',
    JobPostType.partTime => 'Part-time',
    JobPostType.fullTime => 'Full-time',
  };
}

String _deadlineLabel(DateTime? deadline) {
  if (deadline == null) return '';
  return AppDateFormatter.formatVietnameseDate(deadline);
}

List<String> _visibleTags(JobPost job) {
  return job.tags
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .take(3)
      .toList(growable: false);
}
