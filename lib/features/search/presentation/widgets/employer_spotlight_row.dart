import 'package:flutter/material.dart';

import '../../../../features/candidate/domain/job_post.dart';

/// "Nhà tuyển dụng nổi bật" — dạng Instagram Stories.
///
/// Derive từ danh sách job thật: group theo employerId,
/// lấy employerName + employerAvatarUrl.
/// Khi nhà tuyển dụng đăng job mới → tự động xuất hiện ở đây.
class EmployerSpotlightRow extends StatelessWidget {
  const EmployerSpotlightRow({
    super.key,
    required this.jobs,
    required this.selectedEmployerId,
    required this.onEmployerTap,
  });

  final List<JobPost> jobs;
  final String selectedEmployerId;
  final ValueChanged<String> onEmployerTap; // truyền employerId

  /// Group jobs → unique employers, sort theo số job nhiều nhất
  List<_EmployerSpot> _buildSpots() {
    final map = <String, _EmployerSpot>{};
    for (final job in jobs) {
      final id = job.employerId;
      if (id.isEmpty) continue;
      if (map.containsKey(id)) {
        map[id] = map[id]!.copyWith(jobCount: map[id]!.jobCount + 1);
      } else {
        map[id] = _EmployerSpot(
          employerId: id,
          name: job.companyName ?? job.employerName,
          avatarUrl: job.employerAvatarUrl,
          jobCount: 1,
        );
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.jobCount.compareTo(a.jobCount));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final spots = _buildSpots();
    if (spots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Nhà tuyển dụng nổi bật',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: spots.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (_, i) => _SpotItem(
              spot: spots[i],
              isSelected: spots[i].employerId == selectedEmployerId,
              onTap: () => onEmployerTap(spots[i].employerId),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _EmployerSpot {
  const _EmployerSpot({
    required this.employerId,
    required this.name,
    required this.jobCount,
    this.avatarUrl,
  });

  final String employerId;
  final String name;
  final String? avatarUrl;
  final int jobCount;

  _EmployerSpot copyWith({int? jobCount}) => _EmployerSpot(
    employerId: employerId,
    name: name,
    avatarUrl: avatarUrl,
    jobCount: jobCount ?? this.jobCount,
  );
}

// ── Gradient ring palette ─────────────────────────────────────────────────────

const _ringGradients = [
  [Color(0xFFF09433), Color(0xFFE6683C), Color(0xFFDC2743), Color(0xFFCC2366)],
  [Color(0xFF405DE6), Color(0xFF5851DB), Color(0xFF833AB4)],
  [Color(0xFF12C2E9), Color(0xFFC471ED), Color(0xFFF64F59)],
  [Color(0xFFf7971e), Color(0xFFffd200)],
  [Color(0xFF11998e), Color(0xFF38ef7d)],
  [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
  [Color(0xFFe52d27), Color(0xFFb31217)],
  [Color(0xFF1D976C), Color(0xFF93F9B9)],
];

List<Color> _ringFor(String id) {
  final idx = id.hashCode.abs() % _ringGradients.length;
  return _ringGradients[idx];
}

// ── Story item ────────────────────────────────────────────────────────────────

class _SpotItem extends StatelessWidget {
  const _SpotItem({
    required this.spot,
    required this.isSelected,
    required this.onTap,
  });

  final _EmployerSpot spot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = _ringFor(spot.employerId);
    // Short display name — lấy tối đa 10 ký tự
    final shortName = spot.name.length > 10
        ? '${spot.name.substring(0, 9)}…'
        : spot.name;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Gradient ring ─────────────────────────────────────────
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // selected → viền xám (đã xem)
                gradient: isSelected
                    ? null
                    : LinearGradient(
                        colors: ring,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isSelected ? const Color(0xFFD1D5DB) : null,
                boxShadow: isSelected
                    ? null
                    : [
                        BoxShadow(
                          color: ring[0].withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              // ── White gap ───────────────────────────────────────────
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: _AvatarContent(
                      avatarUrl: spot.avatarUrl,
                      name: spot.name,
                      employerId: spot.employerId,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 5),

            // ── Employer name ─────────────────────────────────────────
            Text(
              shortName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Job count ─────────────────────────────────────────────
            Text(
              '${spot.jobCount} ca',
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar content ────────────────────────────────────────────────────────────

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({
    required this.avatarUrl,
    required this.name,
    required this.employerId,
  });

  final String? avatarUrl;
  final String name;
  final String employerId;

  /// Màu nền placeholder từ employerId
  Color get _placeholderBg {
    const colors = [
      Color(0xFFEDE9FE),
      Color(0xFFFCE7F3),
      Color(0xFFFEF3C7),
      Color(0xFFD1FAE5),
      Color(0xFFDBEAFE),
      Color(0xFFFEE2E2),
    ];
    return colors[employerId.hashCode.abs() % colors.length];
  }

  Color get _placeholderFg {
    const colors = [
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFFD97706),
      Color(0xFF059669),
      Color(0xFF2563EB),
      Color(0xFFDC2626),
    ];
    return colors[employerId.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return Image.network(
        avatarUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _PlaceholderCircle(
            bg: _placeholderBg,
            fg: _placeholderFg,
            initials: _initials(name),
          );
        },
        errorBuilder: (_, _, _) => _PlaceholderCircle(
          bg: _placeholderBg,
          fg: _placeholderFg,
          initials: _initials(name),
        ),
      );
    }
    return _PlaceholderCircle(
      bg: _placeholderBg,
      fg: _placeholderFg,
      initials: _initials(name),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _PlaceholderCircle extends StatelessWidget {
  const _PlaceholderCircle({
    required this.bg,
    required this.fg,
    required this.initials,
  });

  final Color bg;
  final Color fg;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }
}
