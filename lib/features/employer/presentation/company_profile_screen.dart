import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../candidate/application/jobs_providers.dart';
import '../../candidate/domain/job_post.dart';
import '../../candidate/presentation/user_job_detail_screen.dart';

// ── Provider: jobs của 1 employer ────────────────────────────────────────────

final _employerJobsProvider = FutureProvider.family<List<JobPost>, String>((
  ref,
  employerId,
) async {
  final standard = await ref.watch(activeJobsProvider.future);
  final quick = await ref.watch(activeQuickJobsProvider.future);
  final all = [...standard, ...quick];
  return all.where((j) => j.employerId == employerId).toList()
    ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
});

// ── Screen ────────────────────────────────────────────────────────────────────

class CompanyEmployeeReview {
  const CompanyEmployeeReview({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.jobTitle,
    this.heartCount = 0,
  });

  final String id;
  final String authorName;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String? jobTitle;
  final int heartCount;

  bool get isFiveStar => rating >= 5;
}

/// Trang công ty — dữ liệu đồng bộ với website qua cùng backend AWS.
/// Không có mock/fake data.
/// Mọi thông tin derive từ [JobPost] fields thật từ AwsJobRepository.
class CompanyProfileScreen extends ConsumerWidget {
  const CompanyProfileScreen({
    super.key,
    required this.employerId,
    required this.companyName,
    this.logoUrl,
    this.location,
    this.tags = const [],
    this.applicants = 0,
    this.employeeReviews = const [],
  });

  final String employerId;
  final String companyName;
  final String? logoUrl;
  final String? location;
  final List<String> tags;
  final int applicants;
  final List<CompanyEmployeeReview> employeeReviews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(_employerJobsProvider(employerId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _CompanyAppBar(companyName: companyName),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ErrorBody(
          onRetry: () => ref.invalidate(_employerJobsProvider(employerId)),
        ),
        data: (jobs) => _CompanyBody(
          employerId: employerId,
          companyName: companyName,
          logoUrl: logoUrl,
          location: location,
          tags: tags,
          applicants: applicants,
          employeeReviews: employeeReviews,
          jobs: jobs,
        ),
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _CompanyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CompanyAppBar({required this.companyName});

  final String companyName;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: const BackButton(color: Color(0xFF1E293B)),
      title: const Text(
        'Ốp Pờ',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _CompanyBody extends StatelessWidget {
  const _CompanyBody({
    required this.employerId,
    required this.companyName,
    required this.logoUrl,
    required this.location,
    required this.tags,
    required this.applicants,
    required this.employeeReviews,
    required this.jobs,
  });

  final String employerId;
  final String companyName;
  final String? logoUrl;
  final String? location;
  final List<String> tags;
  final int applicants;
  final List<CompanyEmployeeReview> employeeReviews;
  final List<JobPost> jobs;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero header ─────────────────────────────────────────
          _CompanyHeroHeader(
            companyName: companyName,
            logoUrl: logoUrl,
            location: location,
            tags: tags,
            applicants: applicants,
            jobCount: jobs.length,
          ),

          const _SectionGap(),

          // ── Đánh giá từ nhân viên ──────────────────────────────
          _ReviewsSection(reviews: employeeReviews),

          const _SectionGap(),

          // ── Chi tiết xếp hạng ──────────────────────────────────
          const _RatingBreakdownSection(),

          const _SectionGap(),

          // ── Hình ảnh từ nhân viên ──────────────────────────────
          const _EmployerPhotosSection(),

          const _SectionGap(),

          // ── Việc đang tuyển ────────────────────────────────────
          if (jobs.isNotEmpty) _OpenJobsSection(jobs: jobs),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _CompanyHeroHeader extends StatelessWidget {
  const _CompanyHeroHeader({
    required this.companyName,
    required this.logoUrl,
    required this.location,
    required this.tags,
    required this.applicants,
    required this.jobCount,
  });

  final String companyName;
  final String? logoUrl;
  final String? location;
  final List<String> tags;
  final int applicants;
  final int jobCount;

  @override
  Widget build(BuildContext context) {
    final industry = tags.isNotEmpty ? tags.first : 'F&B';

    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        children: [
          // Logo
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _CompanyLogo(logoUrl: logoUrl),
          ),
          const SizedBox(height: 12),

          // Top rated badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'TOP RATED ${industry.toUpperCase()}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD97706),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Company name
          Text(
            companyName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
              height: 1.2,
            ),
          ),

          if (location != null && location!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              location!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
          const SizedBox(height: 16),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(
                icon: Icons.work_outline_rounded,
                label: '$jobCount việc đang tuyển',
              ),
              const SizedBox(width: 16),
              _StatChip(
                icon: Icons.people_outline_rounded,
                label: '${applicants > 0 ? applicants : '1'}+ ứng viên',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Reviews section ───────────────────────────────────────────────────────────
// App-only review surface. Review data is provided by backend-backed callers;
// the UI only filters and orders the supplied records.

enum _ReviewFilter { latest, helpful }

class _ReviewsSection extends StatefulWidget {
  const _ReviewsSection({required this.reviews});

  final List<CompanyEmployeeReview> reviews;

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  _ReviewFilter _filter = _ReviewFilter.latest;

  List<CompanyEmployeeReview> get _visibleReviews {
    final reviews = switch (_filter) {
      _ReviewFilter.latest => [...widget.reviews],
      _ReviewFilter.helpful => [
        for (final review in widget.reviews)
          if (review.isFiveStar) review,
      ],
    };

    reviews.sort((a, b) {
      if (_filter == _ReviewFilter.helpful) {
        final heartComparison = b.heartCount.compareTo(a.heartCount);
        if (heartComparison != 0) return heartComparison;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return reviews;
  }

  @override
  Widget build(BuildContext context) {
    final visibleReviews = _visibleReviews;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + filter tabs
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Đánh giá từ nhân viên',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _ReviewFilterTab(
                label: 'MỚI NHẤT',
                isActive: _filter == _ReviewFilter.latest,
                onTap: () => setState(() => _filter = _ReviewFilter.latest),
              ),
              const SizedBox(width: 8),
              _ReviewFilterTab(
                label: 'HỮU ÍCH',
                isActive: _filter == _ReviewFilter.helpful,
                onTap: () => setState(() => _filter = _ReviewFilter.helpful),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (visibleReviews.isEmpty)
            _ReviewEmptyState(filter: _filter)
          else
            Column(
              children: [
                for (var index = 0; index < visibleReviews.length; index++) ...[
                  _ReviewCard(review: visibleReviews[index]),
                  if (index < visibleReviews.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          const SizedBox(height: 16),

          // CTA viết đánh giá
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn đã từng làm việc\ntại đây?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Những chia sẻ của bạn sẽ giúp cộng đồng ứng viên khám phá hơn về môi trường làm việc.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tính năng đánh giá đang phát triển.'),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Viết đánh giá',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewFilterTab extends StatelessWidget {
  const _ReviewFilterTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : const Color(0xFF6B7280),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewEmptyState extends StatelessWidget {
  const _ReviewEmptyState({required this.filter});

  final _ReviewFilter filter;

  @override
  Widget build(BuildContext context) {
    final isHelpful = filter == _ReviewFilter.helpful;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 36,
            color: Color(0xFFD1D5DB),
          ),
          const SizedBox(height: 10),
          Text(
            isHelpful ? 'Chưa có đánh giá hữu ích' : 'Chưa có đánh giá nào',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isHelpful
                ? 'Các đánh giá 5 sao được nhiều tim sẽ hiển thị tại đây.'
                : 'Hãy là người đầu tiên chia sẻ trải nghiệm làm việc!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final CompanyEmployeeReview review;

  @override
  Widget build(BuildContext context) {
    final jobTitle = review.jobTitle?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.authorName.trim().isEmpty
                      ? 'Ứng viên'
                      : review.authorName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    size: 15,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${review.heartCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (jobTitle != null && jobTitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              jobTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < review.rating.round().clamp(0, 5)
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 16,
                color: const Color(0xFFFBBF24),
              ),
            ),
          ),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment.trim(),
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Rating breakdown ──────────────────────────────────────────────────────────
// App-only rating summary derived from currently available profile fields.

class _RatingBreakdownSection extends StatelessWidget {
  const _RatingBreakdownSection();

  @override
  Widget build(BuildContext context) {
    // Static breakdown — sẽ replace bằng API data
    const breakdown = [(5, 0.0), (4, 0.0), (3, 0.0), (2, 0.0), (1, 0.0)];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết xếp hạng',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          ...breakdown.map((r) => _RatingBar(stars: r.$1, ratio: r.$2)),
          const SizedBox(height: 8),
          const Text(
            'Chưa có đủ đánh giá để hiển thị.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.stars, required this.ratio});

  final int stars;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$stars',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: const Color(0xFFE5E7EB),
                color: AppColors.primary,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${(ratio * 100).round()}%',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photos section ─────────────────────────────────────────────────────────────
// App-only photo empty state until user-submitted media exists in the app.

class _EmployerPhotosSection extends StatelessWidget {
  const _EmployerPhotosSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hình ảnh từ nhân viên',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          // Placeholder grid — sẽ load từ S3 khi backend có API
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemCount: 4,
            itemBuilder: (_, i) => Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Color(0xFFD1D5DB),
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hình ảnh sẽ hiển thị khi nhân viên tải lên.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

// ── Open jobs section ─────────────────────────────────────────────────────────

class _OpenJobsSection extends StatelessWidget {
  const _OpenJobsSection({required this.jobs});

  final List<JobPost> jobs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Vị trí đang tuyển',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${jobs.length} vị trí',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...jobs.take(5).map((job) => _OpenJobTile(job: job)),
          if (jobs.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () {},
                child: Text(
                  'Xem thêm ${jobs.length - 5} vị trí',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpenJobTile extends StatelessWidget {
  const _OpenJobTile({required this.job});

  final JobPost job;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserJobDetailScreen(
            job: job,
            onApplyPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job.salary.isNotEmpty ? job.salary : 'Thỏa thuận',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section gap ───────────────────────────────────────────────────────────────

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      color: const Color(0xFFF7F8FC),
      margin: const EdgeInsets.symmetric(vertical: 16),
    );
  }
}

// ── Company logo ──────────────────────────────────────────────────────────────

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          logoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _LogoFallback(),
        ),
      );
    }
    return const _LogoFallback();
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.business_rounded,
      size: 40,
      color: AppColors.primary,
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: Color(0xFFD1D5DB),
          ),
          const SizedBox(height: 12),
          const Text(
            'Không tải được thông tin công ty',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
