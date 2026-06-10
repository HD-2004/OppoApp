import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';

import '../../../candidate/domain/job_post.dart';

/// Job card theo ảnh tham khảo:
/// Badge Urgent | Salary
/// Title (2 dòng)
/// Company logo + name + verified icon
/// Location row
/// Time / shift row
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.onTap});

  final JobPost job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUrgent = job.jobType == JobPostType.urgent || job.isQuickJob;
    final company = job.companyName ?? job.employerName;
    final salary = job.salary.isNotEmpty ? job.salary : 'Thỏa thuận';
    final shiftTime = _resolveShiftTime();
    final location = job.location;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Badge urgent + salary
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUrgent) ...[
                  _UrgentBadge(),
                  const Spacer(),
                ] else
                  const Spacer(),
                Text(
                  salary,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isUrgent ? AppColors.secondary : AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Job title
            Text(
              job.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Employment type label (từ jobType của backend)
            if (!isUrgent) ...[
              const SizedBox(height: 2),
              Text(
                job.jobType.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Row 3: Company logo + name + verified
            Row(
              children: [
                _CompanyLogo(logoUrl: job.employerAvatarUrl),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    company,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Verified badge app-only: jobs loaded from the trusted repository
                // are shown as verified until the domain model exposes employer trust.
                const Icon(
                  Icons.verified_rounded,
                  size: 15,
                  color: AppColors.secondary,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Row 4: Location
            if (location.isNotEmpty)
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: location,
                iconColor: const Color(0xFF9CA3AF),
                textColor: const Color(0xFF6B7280),
              ),

            // Row 5: Shift time / work date
            if (shiftTime.isNotEmpty) ...[
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.access_time_rounded,
                text: shiftTime,
                iconColor: AppColors.secondary,
                textColor: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ],
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
        return job.workDate!;
      }
    }
    // Standard job: shiftTime / workHours từ backend
    if (job.shiftTime.isNotEmpty) return job.shiftTime;
    if (job.workHours != null && job.workHours!.isNotEmpty) {
      return job.workHours!;
    }
    return '';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _UrgentBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: Colors.white, size: 12),
          SizedBox(width: 3),
          Text(
            'Urgent',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({this.logoUrl});
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _LogoFallback(),
              ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.iconColor,
    required this.textColor,
    this.fontWeight = FontWeight.w400,
  });

  final IconData icon;
  final String text;
  final Color iconColor;
  final Color textColor;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: fontWeight,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
