import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';

import '../../../../features/candidate/domain/job_post.dart';

/// Card job theo ảnh tham khảo:
/// [Icon ngành]  Tên ca - Giờ        [Badge]
///               Tên công ty ✓
/// 📍 x.x km    🕐 giờ - giờ
/// LƯƠNG: xx.000đ/giờ              [Ứng tuyển]
class SearchJobCard extends StatelessWidget {
  const SearchJobCard({
    super.key,
    required this.job,
    required this.onTap,
    required this.onApply,
  });

  final JobPost job;
  final VoidCallback onTap;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final company = job.companyName ?? job.employerName;
    final salary = job.salary.isNotEmpty ? job.salary : 'Thỏa thuận';
    final shiftTime = _resolveShiftTime();
    final badge = _resolveBadge();
    final daysAgo = DateTime.now().difference(job.postedAt).inDays;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: icon + title + badge ──────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _JobIcon(tags: job.tags, isQuick: job.isQuickJob),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              job.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            _Badge(label: badge.$1, color: badge.$2),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              company,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Row 2: distance + shift time ────────────────────────────
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 3),
                // Distance: no field in schema → show location district
                Text(
                  _shortLocation(job.location),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (shiftTime.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      shiftTime,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // ── Divider ──────────────────────────────────────────────────
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 10),

            // ── Row 3: salary + apply button ────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LƯƠNG',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        salary,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
                // Posted time
                if (daysAgo == 0)
                  const _PostedLabel(text: 'Hôm nay', color: Color(0xFF10B981))
                else if (daysAgo == 1)
                  const _PostedLabel(text: 'Hôm qua', color: Color(0xFF6B7280)),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Ứng tuyển',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _resolveShiftTime() {
    if (job.startTime != null &&
        job.endTime != null &&
        job.startTime!.isNotEmpty &&
        job.endTime!.isNotEmpty) {
      return '${job.startTime} - ${job.endTime}';
    }
    if (job.shiftTime.isNotEmpty) return job.shiftTime;
    if (job.workHours != null && job.workHours!.isNotEmpty) {
      return job.workHours!;
    }
    if (job.workDate != null && job.workDate!.isNotEmpty) return job.workDate!;
    return '';
  }

  (String, Color)? _resolveBadge() {
    final now = DateTime.now();
    final diff = now.difference(job.postedAt);
    // "MỚI" if posted within 24h
    if (diff.inHours < 24) return ('MỚI', AppColors.primary);
    // "CẦN GẤP" for urgent/quick jobs
    if (job.isQuickJob || job.jobType == JobPostType.urgent) {
      return ('CẦN GẤP', const Color(0xFFDC2626));
    }
    // "CUỐI TUẦN" if workDays contains weekend keywords
    final wd = job.workDays?.toLowerCase() ?? '';
    if (wd.contains('cuối tuần') ||
        wd.contains('t7') ||
        wd.contains('chủ nhật') ||
        wd.contains('cn')) {
      return ('CUỐI TUẦN', const Color(0xFF7C3AED));
    }
    return null;
  }

  String _shortLocation(String location) {
    if (location.isEmpty) return '—';
    return location.split(',').first.trim();
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Icon ngành dựa trên tags job
class _JobIcon extends StatelessWidget {
  const _JobIcon({required this.tags, required this.isQuick});

  final List<String> tags;
  final bool isQuick;

  @override
  Widget build(BuildContext context) {
    final icon = _pickIcon();
    final bg = _pickBg();

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: bg, size: 24),
    );
  }

  IconData _pickIcon() {
    final joined = tags.join(' ').toLowerCase();
    if (joined.contains('cafe') || joined.contains('coffee')) {
      return Icons.coffee_rounded;
    }
    if (joined.contains('phục vụ') || joined.contains('nhà hàng')) {
      return Icons.restaurant_rounded;
    }
    if (joined.contains('bếp') || joined.contains('cook')) {
      return Icons.soup_kitchen_rounded;
    }
    if (joined.contains('bar') || joined.contains('pha chế')) {
      return Icons.local_bar_rounded;
    }
    if (joined.contains('khách sạn') || joined.contains('hotel')) {
      return Icons.hotel_rounded;
    }
    if (isQuick) return Icons.bolt_rounded;
    return Icons.work_outline_rounded;
  }

  Color _pickBg() {
    final joined = tags.join(' ').toLowerCase();
    if (joined.contains('cafe') || joined.contains('coffee')) {
      return const Color(0xFF92400E);
    }
    if (joined.contains('phục vụ') || joined.contains('nhà hàng')) {
      return AppColors.primary;
    }
    if (joined.contains('bếp')) return const Color(0xFF065F46);
    if (joined.contains('bar')) return const Color(0xFF6D28D9);
    if (isQuick) return const Color(0xFFDC2626);
    return AppColors.primary;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PostedLabel extends StatelessWidget {
  const _PostedLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
    );
  }
}
