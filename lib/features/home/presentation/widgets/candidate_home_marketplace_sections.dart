import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/config/s3_asset_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../candidate/domain/job_post.dart';
import '../../../employer_packages/domain/employer_package.dart';
import '../../../recommendations/domain/job_recommendation.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.displayName,
    required this.searchController,
    required this.onSearchChanged,
    required this.onNotificationTap,
    required this.onChatTap,
    required this.notificationCount,
    required this.chatCount,
  });

  final String displayName;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onNotificationTap;
  final VoidCallback onChatTap;
  final int notificationCount;
  final int chatCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Mở menu',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        foregroundColor: AppColors.textOnPrimary,
                        fixedSize: const Size(44, 44),
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Ốp Pờ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  _HeaderBadgeButton(
                    tooltip: 'Thông báo',
                    icon: Icons.notifications_none_rounded,
                    count: notificationCount,
                    onPressed: onNotificationTap,
                  ),
                  const SizedBox(width: 10),
                  _HeaderBadgeButton(
                    tooltip: 'Tin nhắn',
                    icon: Icons.chat_bubble_outline_rounded,
                    count: chatCount,
                    onPressed: onChatTap,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '${_greeting()}, $displayName!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 18),
              HomeSearchBar(
                controller: searchController,
                onChanged: onSearchChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 14) return 'Chào buổi trưa';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }
}

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return SizedBox(
      height: 54,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Tìm việc, công ty, bài đăng...',
          hintStyle: TextStyle(
            color: AppColors.textMutedFor(context),
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
          ),
          filled: true,
          fillColor: isDark ? AppColors.darkSurface : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: AppColors.primaryLight,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class RecommendedJobsSection extends StatelessWidget {
  const RecommendedJobsSection({
    super.key,
    required this.recommendations,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.onSeeAll,
    required this.onJobTap,
    required this.onApply,
  });

  final List<JobRecommendation> recommendations;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;
  final VoidCallback onSeeAll;
  final ValueChanged<JobPost> onJobTap;
  final ValueChanged<JobPost> onApply;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Việc hợp bạn nhất',
      trailing: recommendations.isEmpty
          ? null
          : _SeeAllButton(onPressed: onSeeAll),
      child: Builder(
        builder: (context) {
          if (isLoading) return const _HorizontalSkeleton(height: 310);
          if (hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: EmptyState(
                icon: Icons.tips_and_updates_outlined,
                title: 'Chưa lấy được gợi ý',
                message: 'Bạn thử tải lại để hệ thống gợi ý việc phù hợp hơn.',
                actionLabel: 'Thử lại',
                onAction: onRetry,
              ),
            );
          }
          if (recommendations.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: EmptyState(
                title: 'Tạm thời chưa có việc phù hợp.',
                message: 'Bạn cập nhật lại hồ sơ cá nhân để có gợi ý mới nha.',
                illustrationAsset: 'img/intro.png',
              ),
            );
          }

          return SizedBox(
            height: 310,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: recommendations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, index) {
                final item = recommendations[index];
                return JobCard(
                  job: item.job,
                  matchScore: item.matchScore,
                  onTap: () => onJobTap(item.job),
                  onApply: () => onApply(item.job),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class SponsoredBannerSection extends StatefulWidget {
  const SponsoredBannerSection({
    super.key,
    required this.banners,
    required this.isLoading,
  });

  final List<BannerAd> banners;
  final bool isLoading;

  @override
  State<SponsoredBannerSection> createState() => _SponsoredBannerSectionState();
}

class _SponsoredBannerSectionState extends State<SponsoredBannerSection> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 7), (timer) {
      final total = _getBannerCount();
      if (total <= 1) return;
      _currentPage = (_currentPage + 1) % total;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  int _getBannerCount() {
    return widget.banners.isNotEmpty
        ? widget.banners.length
        : S3AssetConfig.candidateBanners.length;
  }

  String _getBannerImageUrl(int index) {
    if (widget.banners.isNotEmpty) {
      return widget.banners[index].imageUrl;
    }
    return S3AssetConfig.candidateBanners[index];
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: _SkeletonBox(height: 154, radius: 24),
      );
    }

    final count = _getBannerCount();
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(
        children: [
          SizedBox(
            height: 154,
            child: PageView.builder(
              controller: _pageController,
              itemCount: count,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
                _startAutoPlay(); // Reset timer on manual scroll
              },
              itemBuilder: (context, index) {
                final imageUrl = _getBannerImageUrl(index);
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.primarySoft,
                        child: const Icon(
                          Icons.image_not_supported_rounded,
                          color: AppColors.primaryLight,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              count,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppColors.primary
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TopCompaniesSection extends StatelessWidget {
  const TopCompaniesSection({
    super.key,
    required this.companies,
    required this.isLoading,
    required this.onSeeAll,
  });

  final List<CompanyRankItem> companies;
  final bool isLoading;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && companies.isEmpty) return const SizedBox.shrink();

    return _SectionShell(
      title: 'Top công ty đang tuyển nhiều fresher nhất',
      highlightedTitlePart: 'tuyển nhiều fresher',
      trailing: companies.isEmpty ? null : _SeeAllButton(onPressed: onSeeAll),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: isLoading
            ? const _SkeletonBox(height: 314, radius: 24)
            : Container(
                decoration: BoxDecoration(
                  color: AppColors.textOnPrimary,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < companies.length; index++) ...[
                      CompanyRankCard(item: companies[index]),
                      if (index < companies.length - 1)
                        const Divider(height: 1, color: AppColors.border),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class DirectionJobsSection extends StatelessWidget {
  const DirectionJobsSection({
    super.key,
    required this.jobs,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.onSeeAll,
    required this.onJobTap,
    required this.onApply,
  });

  final List<JobPost> jobs;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;
  final VoidCallback onSeeAll;
  final ValueChanged<JobPost> onJobTap;
  final ValueChanged<JobPost> onApply;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Việc hợp hướng đi',
      trailing: jobs.isEmpty ? null : _SeeAllButton(onPressed: onSeeAll),
      child: Builder(
        builder: (context) {
          if (isLoading) return const _HorizontalSkeleton(height: 310);
          if (hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Không tải được danh sách việc',
                message: 'Bạn thử tải lại sau vài giây nha.',
                actionLabel: 'Thử lại',
                onAction: onRetry,
              ),
            );
          }
          if (jobs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Chưa có việc để hiển thị.',
                message: 'Khi backend trả về dữ liệu, mục này sẽ tự cập nhật.',
              ),
            );
          }

          return SizedBox(
            height: 310,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, index) => JobCard(
                job: jobs[index],
                onTap: () => onJobTap(jobs[index]),
                onApply: () => onApply(jobs[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.illustrationAsset,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData? icon;
  final String? illustrationAsset;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (illustrationAsset != null)
            Image.asset(
              illustrationAsset!,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _EmptyIcon(icon: icon),
            )
          else
            _EmptyIcon(icon: icon),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.22,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$title $message'.contains(
                  'Tạm thời chưa có việc phù hợp. Bạn cập nhật lại hồ sơ cá nhân để có gợi ý mới nha.',
                )
                ? 'Tạm thời chưa có việc phù hợp. Bạn cập nhật lại hồ sơ cá nhân để có gợi ý mới nha.'
                : message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 15,
              height: 1.35,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primaryLight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    required this.onApply,
    this.matchScore,
  });

  final JobPost job;
  final VoidCallback onTap;
  final VoidCallback onApply;
  final int? matchScore;

  @override
  Widget build(BuildContext context) {
    final companyName = companyNameOf(job);
    return SizedBox(
      width: 286,
      child: Material(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderFor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (job.isQuickJob || job.jobType == JobPostType.urgent || job.isAiScreeningEnabled)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (job.isQuickJob || job.jobType == JobPostType.urgent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFFED7AA),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.local_fire_department_rounded,
                                            size: 11,
                                            color: Color(0xFFF97316),
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'Tuyển gấp',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFC2410C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (job.isAiScreeningEnabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3E8FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFC084FC),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.auto_awesome,
                                            size: 11,
                                            color: Color(0xFF7C3AED),
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'Phỏng vấn AI',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF6D28D9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          Text(
                            job.title.trim().isEmpty
                                ? 'Không công khai'
                                : job.title.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimaryFor(context),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            companyName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMutedFor(context),
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    LogoBox(name: companyName, imageUrl: job.employerAvatarUrl),
                  ],
                ),
                const Spacer(),
                _MetaLine(
                  icon: Icons.payments_outlined,
                  label: publicOrHidden(job.salary),
                ),
                const SizedBox(height: 9),
                _MetaLine(
                  icon: Icons.location_on_outlined,
                  label: publicOrHidden(job.location),
                ),
                const SizedBox(height: 9),
                _MetaLine(
                  icon: Icons.schedule_rounded,
                  label: publicOrHidden(scheduleOf(job)),
                ),
                const SizedBox(height: 13),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (matchScore != null)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.softPrimaryFor(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.borderFor(context),
                            ),
                          ),
                          child: Text(
                            'Phù hợp: $matchScore%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimaryFor(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    FilledButton(
                      onPressed: onApply,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Ứng tuyển'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CompanyRankCard extends StatelessWidget {
  const CompanyRankCard({super.key, required this.item});

  final CompanyRankItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: item.rank <= 3
                  ? Icon(
                      Icons.workspace_premium_rounded,
                      color: switch (item.rank) {
                        1 => AppColors.primary,
                        2 => AppColors.primaryLight,
                        _ => AppColors.accent,
                      },
                      size: 34,
                    )
                  : Text(
                      '${item.rank}',
                      style: TextStyle(
                        color: AppColors.textSecondaryFor(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          LogoBox(name: item.name, imageUrl: item.logoUrl, size: 58),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.activeJobCount} việc đang tuyển',
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 16,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textPrimaryFor(context),
          ),
        ],
      ),
    );
  }
}

class CompanyRankItem {
  const CompanyRankItem({
    required this.rank,
    required this.name,
    required this.activeJobCount,
    this.logoUrl,
  });

  final int rank;
  final String name;
  final int activeJobCount;
  final String? logoUrl;
}

class LogoBox extends StatelessWidget {
  const LogoBox({super.key, required this.name, this.imageUrl, this.size = 58});

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim();
    Widget child = Icon(
      Icons.business_rounded,
      color: AppColors.disabledFor(context),
    );
    if (image != null && image.isNotEmpty) {
      if (image.startsWith('data:image')) {
        try {
          child = Image.memory(
            base64Decode(image.split(',').last),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.business_rounded,
              color: AppColors.disabledFor(context),
            ),
          );
        } catch (_) {
          child = Icon(
            Icons.business_rounded,
            color: AppColors.disabledFor(context),
          );
        }
      } else {
        child = Image.network(
          image,
          fit: BoxFit.contain,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            return wasSynchronouslyLoaded || frame != null
                ? child
                : Icon(
                    Icons.business_rounded,
                    color: AppColors.disabledFor(context),
                  );
          },
          errorBuilder: (_, _, _) => Icon(
            Icons.business_rounded,
            color: AppColors.disabledFor(context),
          ),
        );
      }
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.fieldFill(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: child,
    );
  }
}



class _HeaderBadgeButton extends StatelessWidget {
  const _HeaderBadgeButton({
    required this.tooltip,
    required this.icon,
    required this.count,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textPrimary,
            fixedSize: const Size(50, 50),
            shape: const CircleBorder(),
          ),
          icon: Icon(icon, size: 25),
        ),
        if (count > 0)
          Positioned(
            right: -1,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.child,
    this.highlightedTitlePart,
    this.trailing,
  });

  final String title;
  final String? highlightedTitlePart;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _SectionTitle(title, highlightedTitlePart)),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.highlight);

  final String title;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    if (highlight == null || !title.contains(highlight!)) {
      return Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimaryFor(context),
          fontSize: 29,
          fontWeight: FontWeight.w900,
          height: 1.12,
        ),
      );
    }

    final before = title.substring(0, title.indexOf(highlight!));
    final after = title.substring(
      title.indexOf(highlight!) + highlight!.length,
    );
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: AppColors.textPrimaryFor(context),
          fontSize: 29,
          fontWeight: FontWeight.w900,
          height: 1.12,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: highlight,
            style: const TextStyle(color: AppColors.primaryLight),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward_rounded),
      label: const Text('Xem tất cả'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.borderFor(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.textMutedFor(context)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyIcon extends StatelessWidget {
  const _EmptyIcon({this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon ?? Icons.inbox_outlined,
        color: AppColors.primaryLight,
        size: 38,
      ),
    );
  }
}

class _HorizontalSkeleton extends StatelessWidget {
  const _HorizontalSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: 2,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) =>
            _SkeletonBox(width: 286, height: height, radius: 24),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, required this.height, required this.radius});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

String companyNameOf(JobPost job) {
  final companyName = job.companyName?.trim();
  if (companyName != null && companyName.isNotEmpty) return companyName;
  final employerName = job.employerName.trim();
  if (employerName.isNotEmpty) return employerName;
  return 'Không công khai';
}

String scheduleOf(JobPost job) {
  final start = job.startTime?.trim();
  final end = job.endTime?.trim();
  if (start != null && start.isNotEmpty && end != null && end.isNotEmpty) {
    return '$start - $end';
  }
  if (job.shiftTime.trim().isNotEmpty) return job.shiftTime.trim();
  if (job.workHours?.trim().isNotEmpty == true) return job.workHours!.trim();
  return '';
}

String publicOrHidden(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Không công khai' : trimmed;
}

String postedTimeLabel(DateTime postedAt) {
  if (postedAt.millisecondsSinceEpoch == 0) return 'Không công khai';
  final diff = DateTime.now().difference(postedAt);
  if (diff.isNegative || diff.inMinutes < 1) return 'Vừa đăng';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  return '${diff.inDays} ngày trước';
}
