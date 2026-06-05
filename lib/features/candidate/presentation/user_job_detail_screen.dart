import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../employer/presentation/company_profile_screen.dart';
import '../domain/job_post.dart';

/// Màn hình chi tiết công việc — đồng bộ dữ liệu với website qua cùng backend.
/// Dữ liệu: AwsJobRepository → REST API AWS.
/// Không có mock/fake data — mọi field hiển thị từ [JobPost] backend thật.
class UserJobDetailScreen extends StatelessWidget {
  const UserJobDetailScreen({
    super.key,
    required this.job,
    required this.onApplyPressed,
  });

  final JobPost job;
  final VoidCallback onApplyPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Scrollable content ─────────────────────────────────────
          CustomScrollView(
            slivers: [
              // ── Hero image + AppBar ──────────────────────────────
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: const Color(0xFF1E3A8A),
                systemOverlayStyle: SystemUiOverlayStyle.light,
                leading: _CircleIconBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                actions: [
                  _CircleIconBtn(icon: Icons.share_outlined, onTap: () {}),
                  _CircleIconBtn(
                    icon: Icons.bookmark_border_rounded,
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroBanner(job: job),
                ),
              ),

              // ── Body content ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick info cards
                    _QuickInfoSection(job: job),

                    const _SectionDivider(),

                    // Mô tả công việc
                    if (job.description.isNotEmpty)
                      _DescriptionSection(text: job.description),

                    // Yêu cầu
                    if (job.requirements != null &&
                        job.requirements!.isNotEmpty) ...[
                      const _SectionDivider(),
                      _RequirementsSection(text: job.requirements!),
                    ],

                    // Quyền lợi
                    if (job.benefits != null && job.benefits!.isNotEmpty) ...[
                      const _SectionDivider(),
                      _BenefitsSection(text: job.benefits!),
                    ],

                    // Thông tin nhà tuyển dụng
                    const _SectionDivider(),
                    _EmployerInfoCard(job: job),

                    // Vị trí tương tự — từ tags/jobType, không mock
                    const _SectionDivider(),
                    _SimilarPositions(job: job),

                    // Bottom spacing cho sticky button
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),

          // ── Sticky bottom apply button ─────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StickyApplyBar(onApply: onApplyPressed),
          ),
        ],
      ),
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.job});

  final JobPost job;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        job.employerAvatarUrl != null && job.employerAvatarUrl!.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background — ảnh công ty từ S3 hoặc gradient mặc định
        hasImage
            ? Image.network(
                job.employerAvatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _DefaultHeroBg(),
              )
            : const _DefaultHeroBg(),

        // Dark gradient overlay
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Color(0xCC000000),
              ],
              stops: [0, 0.4, 1],
            ),
          ),
        ),

        // Title + company + badge
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job type badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _badgeColor(job.jobType),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _badgeLabel(job.jobType),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Job title
              Text(
                job.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Company name
              Text(
                job.companyName ?? job.employerName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _badgeColor(JobPostType type) {
    return switch (type) {
      JobPostType.urgent => const Color(0xFFF97316),
      JobPostType.partTime => const Color(0xFF7C3AED),
      JobPostType.fullTime => const Color(0xFF1E3A8A),
    };
  }

  String _badgeLabel(JobPostType type) {
    return switch (type) {
      JobPostType.urgent => 'Tuyển gấp',
      JobPostType.partTime => 'Part-time',
      JobPostType.fullTime => 'Full-time',
    };
  }
}

class _DefaultHeroBg extends StatelessWidget {
  const _DefaultHeroBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.business_rounded, size: 72, color: Colors.white24),
      ),
    );
  }
}

// ── Circle icon button trên AppBar ────────────────────────────────────────────

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ── Quick info section ────────────────────────────────────────────────────────

class _QuickInfoSection extends StatelessWidget {
  const _QuickInfoSection({required this.job});

  final JobPost job;

  @override
  Widget build(BuildContext context) {
    final shiftTime = _resolveShiftTime();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        children: [
          if (job.salary.isNotEmpty)
            _InfoTile(
              icon: Icons.payments_outlined,
              iconBg: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF1E3A8A),
              label: 'MỨC LƯƠNG',
              value: job.salary,
              valueStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          if (job.location.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.location_on_outlined,
              iconBg: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF1E3A8A),
              label: 'ĐỊA ĐIỂM',
              value: job.location,
            ),
          ],
          if (shiftTime.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.access_time_rounded,
              iconBg: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF1E3A8A),
              label: 'THỜI GIAN',
              value: shiftTime,
            ),
          ],
        ],
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
    if (job.workDays != null && job.workDays!.isNotEmpty) {
      return job.workDays!;
    }
    return '';
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style:
                    valueStyle ??
                    const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section divider ───────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      color: const Color(0xFFF7F8FC),
      margin: const EdgeInsets.symmetric(vertical: 16),
    );
  }
}

// ── Section header (— Tiêu đề) ────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Description section ───────────────────────────────────────────────────────

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Parse bullet points nếu có (dấu • hoặc - hoặc \n)
    final lines = _parseLines(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Mô tả công việc'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) => _ContentLine(text: line)).toList(),
          ),
        ),
      ],
    );
  }

  List<String> _parseLines(String raw) {
    return raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }
}

// ── Requirements section ──────────────────────────────────────────────────────

class _RequirementsSection extends StatelessWidget {
  const _RequirementsSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Yêu cầu'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: lines
                .map((line) => _RequirementCard(text: line))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Tách label: value nếu có dấu :
    final colonIdx = text.indexOf(':');
    String? label;
    String body = text;
    if (colonIdx > 0 && colonIdx < 30) {
      label = text.substring(0, colonIdx).trim();
      body = text.substring(colonIdx + 1).trim();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null) ...[
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.5,
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

// ── Benefits section ──────────────────────────────────────────────────────────

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Quyền lợi'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: lines.map((line) => _BenefitRow(text: line)).toList(),
          ),
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final clean = text.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              clean,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Content line (description bullets) ───────────────────────────────────────

class _ContentLine extends StatelessWidget {
  const _ContentLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isBullet =
        text.startsWith('•') || text.startsWith('-') || text.startsWith('*');
    final clean = isBullet
        ? text.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim()
        : text;

    if (isBullet) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: CircleAvatar(
                radius: 3,
                backgroundColor: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                clean,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        clean,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF374151),
          height: 1.7,
        ),
      ),
    );
  }
}

// ── Employer info card ────────────────────────────────────────────────────────

class _EmployerInfoCard extends StatelessWidget {
  const _EmployerInfoCard({required this.job});

  final JobPost job;

  @override
  Widget build(BuildContext context) {
    final company = job.companyName ?? job.employerName;
    final avatarUrl = job.employerAvatarUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin nhà tuyển dụng',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),

            // Logo + name
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const _CompanyIconFallback(),
                          ),
                        )
                      : const _CompanyIconFallback(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      // applicants count nếu có
                      if (job.applicants > 0)
                        Text(
                          '${job.applicants}+ ứng viên',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Tags nếu có
            if (job.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Lĩnh vực',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  const Spacer(),
                  Text(
                    job.tags.take(2).join(' / '),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // View company button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CompanyProfileScreen(
                        employerId: job.employerId,
                        companyName: job.companyName ?? job.employerName,
                        logoUrl: job.employerAvatarUrl,
                        location: job.location,
                        tags: job.tags,
                        applicants: job.applicants,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A8A),
                  side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Xem trang công ty',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyIconFallback extends StatelessWidget {
  const _CompanyIconFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.business_rounded,
      color: Color(0xFF1E3A8A),
      size: 26,
    );
  }
}

// ── Similar positions ─────────────────────────────────────────────────────────
// Derive từ tags/location của job thật — không hardcode

class _SimilarPositions extends StatelessWidget {
  const _SimilarPositions({required this.job});

  final JobPost job;

  @override
  Widget build(BuildContext context) {
    // App-only similar jobs area: keep a clear empty state until this screen
    // receives a list of related jobs from its caller.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VỊ TRÍ TƯƠNG TỰ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.work_outline_rounded,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Xem thêm việc làm tại ${job.location.split(',').first.trim()}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sticky apply bar ──────────────────────────────────────────────────────────

class _StickyApplyBar extends StatelessWidget {
  const _StickyApplyBar({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onApply,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Ứng tuyển ngay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
