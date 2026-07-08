import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/config/s3_asset_config.dart';
import '../../../../core/formatters/app_date_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../candidate/domain/job_post.dart';
import '../../../candidate/domain/job_recruitment_window.dart';
import '../../../candidate/domain/job_work_schedule.dart';
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

  static const double _jobCardHeight = 352;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Việc hợp bạn nhất',
      trailing: recommendations.isEmpty
          ? null
          : _SeeAllButton(onPressed: onSeeAll),
      child: Builder(
        builder: (context) {
          if (isLoading && recommendations.isEmpty) {
            return const _HorizontalSkeleton(height: _jobCardHeight);
          }
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
            height: _jobCardHeight,
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
    this.onBannerTap,
    this.autoSlideInterval = const Duration(seconds: 4),
    this.slideAnimationDuration = const Duration(milliseconds: 450),
  });

  /// Standard ad-banner aspect ratio (width : height). Banners are a fixed ad
  /// slot, so the frame keeps this ratio and derives its height from the
  /// available phone width — staying correct across all screen sizes without a
  /// hardcoded pixel height.
  ///
  /// This is the official banner ratio (~3:1). Employer web uploads should
  /// target 1500x500 or 1600x517 so images fill the frame without letterboxing
  /// or cropping. Images that deviate from this ratio still display safely:
  /// they are shown uncropped ([BoxFit.contain]) over a blurred fill, so text
  /// and logos are never cut off.
  static const double bannerAspectRatio = 1600 / 517;

  final List<BannerAd> banners;
  final bool isLoading;

  /// Invoked when a banner backed by real data is tapped. Null for fallback
  /// banners that have no associated [BannerAd].
  final ValueChanged<BannerAd>? onBannerTap;
  final Duration autoSlideInterval;
  final Duration slideAnimationDuration;

  @override
  State<SponsoredBannerSection> createState() => _SponsoredBannerSectionState();
}

class _SponsoredBannerSectionState extends State<SponsoredBannerSection> {
  late final PageController _pageController;
  Timer? _autoSlideTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
    _syncAutoSlideTimer();
  }

  @override
  void didUpdateWidget(covariant SponsoredBannerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_bannerCount != _bannerCountFor(oldWidget) ||
        widget.autoSlideInterval != oldWidget.autoSlideInterval) {
      if (_currentPage >= _bannerCount) {
        _currentPage = 0;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      }
      _syncAutoSlideTimer();
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  int get _bannerCount => widget.banners.isNotEmpty
      ? widget.banners.length
      : S3AssetConfig.candidateBanners.length;

  int _bannerCountFor(SponsoredBannerSection widget) =>
      widget.banners.isNotEmpty
      ? widget.banners.length
      : S3AssetConfig.candidateBanners.length;

  String _bannerImageUrl(int index) {
    if (widget.banners.isNotEmpty) {
      return widget.banners[index].imageUrl;
    }
    return S3AssetConfig.candidateBanners[index];
  }

  /// The real banner at [index], or null when showing fallback assets that
  /// have no backing [BannerAd].
  BannerAd? _bannerAt(int index) {
    if (widget.banners.isNotEmpty && index < widget.banners.length) {
      return widget.banners[index];
    }
    return null;
  }

  void _syncAutoSlideTimer() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
    if (_bannerCount <= 1) return;
    _autoSlideTimer = Timer.periodic(widget.autoSlideInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % _bannerCount;
      _pageController.animateToPage(
        nextPage,
        duration: widget.slideAnimationDuration,
        curve: Curves.easeOutCubic,
      );
      _currentPage = nextPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = _bannerCount;
    if (!widget.isLoading && count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Derive the banner height from the actual available width so the
          // frame matches the phone size on every device (no fixed height).
          final bannerHeight =
              constraints.maxWidth / SponsoredBannerSection.bannerAspectRatio;

          if (widget.isLoading) {
            return _SkeletonBox(height: bannerHeight, radius: 22);
          }

          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              SizedBox(
                height: bannerHeight,
                child: PageView.builder(
                  key: const Key('featured-employer-banner-slide-view'),
                  controller: _pageController,
                  itemCount: count,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _syncAutoSlideTimer();
                  },
                  itemBuilder: (context, index) {
                    final banner = _bannerAt(index);
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _CandidateBannerCard(
                        imageUrl: _bannerImageUrl(index),
                        onTap: (banner != null && widget.onBannerTap != null)
                            ? () => widget.onBannerTap!(banner)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              if (count > 1)
                Positioned(
                  bottom: 12,
                  child: _BannerDots(
                    key: const Key('featured-employer-banner-dots'),
                    count: count,
                    activeIndex: _currentPage,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CandidateBannerCard extends StatelessWidget {
  const _CandidateBannerCard({required this.imageUrl, this.onTap});

  final String imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred fill of the same image so the empty space around a
          // letterboxed banner is never an ugly black bar — keeps the frame
          // full while the real image is shown uncropped on top.
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _CandidateBannerFallback(),
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),
          // The actual banner shown in full (no cropping, no distortion).
          Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const _CandidateBannerFallback(),
          ),
          const Positioned(left: 18, top: 16, child: _RecommendationBadge()),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: card,
      ),
    );
  }
}

class _CandidateBannerFallback extends StatelessWidget {
  const _CandidateBannerFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFF2B0D05),
            Color(0xFF8A4F12),
            AppColors.primary,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: Colors.white.withValues(alpha: 0.55),
          size: 48,
        ),
      ),
    );
  }
}

class _RecommendationBadge extends StatelessWidget {
  const _RecommendationBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: Color(0xFFFF8A3D),
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            'Đề xuất',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerDots extends StatelessWidget {
  const _BannerDots({
    super.key,
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.96 : 0.48),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
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

class JobCard extends StatefulWidget {
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
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  bool _isScheduleExpanded = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final companyName = companyNameOf(job);
    return SizedBox(
      width: 286,
      child: Material(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: widget.onTap,
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
                          if (job.isQuickJob ||
                              job.jobType == JobPostType.urgent ||
                              job.isAiScreeningEnabled)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (job.isQuickJob ||
                                      job.jobType == JobPostType.urgent)
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
                const SizedBox(height: 18),
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
                _ScheduleMetaBlock(
                  job: job,
                  isExpanded: _isScheduleExpanded,
                  onToggleExpanded: () {
                    setState(() {
                      _isScheduleExpanded = !_isScheduleExpanded;
                    });
                  },
                ),
                const SizedBox(height: 13),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.matchScore != null)
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
                            'Phù hợp: ${widget.matchScore}%',
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
                      onPressed: widget.onApply,
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

class _ScheduleMetaBlock extends StatelessWidget {
  const _ScheduleMetaBlock({
    required this.job,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  static const int _collapsedShiftCount = 2;

  final JobPost job;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final preview = _SchedulePreviewData.fromJob(job);
    if (!preview.hasContent) {
      return const _MetaLine(
        icon: Icons.schedule_rounded,
        label: 'Không công khai',
      );
    }

    final visibleShiftTimes = isExpanded
        ? preview.shiftTimes
        : preview.shiftTimes.take(_collapsedShiftCount).toList();
    final canExpand = preview.shiftTimes.length > _collapsedShiftCount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.schedule_rounded,
          size: 19,
          color: AppColors.textMutedFor(context),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (visibleShiftTimes.isNotEmpty) ...[
                const SizedBox(height: 3),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topLeft,
                  child: _ShiftTimeList(
                    shiftTimes: visibleShiftTimes,
                    scrollWhenExpanded: isExpanded,
                  ),
                ),
              ],
              if (canExpand) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onToggleExpanded,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(isExpanded ? 'Thu gọn' : 'Xem thêm...'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShiftTimeList extends StatelessWidget {
  const _ShiftTimeList({
    required this.shiftTimes,
    required this.scrollWhenExpanded,
  });

  final List<String> shiftTimes;
  final bool scrollWhenExpanded;

  @override
  Widget build(BuildContext context) {
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < shiftTimes.length; index++)
          Text(
            'Ca ${index + 1}: ${shiftTimes[index]}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
      ],
    );

    if (!scrollWhenExpanded || shiftTimes.length <= 5) {
      return list;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 84),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: list,
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

class _SchedulePreviewData {
  const _SchedulePreviewData({
    required this.dateLabel,
    required this.shiftTimes,
  });

  final String dateLabel;
  final List<String> shiftTimes;

  bool get hasContent => dateLabel.isNotEmpty || shiftTimes.isNotEmpty;

  static _SchedulePreviewData fromJob(JobPost job) {
    final date = _schedulePreviewDate(job);
    final shiftTimes = _schedulePreviewShiftTimes(job, date);
    final dateLabel = date == null
        ? 'Không công khai'
        : formatRecruitmentDate(date);

    return _SchedulePreviewData(dateLabel: dateLabel, shiftTimes: shiftTimes);
  }
}

DateTime? _schedulePreviewDate(JobPost job) {
  final exactDate = AppDateFormatter.parseDateOnly(job.workDate);
  if (exactDate != null) {
    return exactDate;
  }

  final recruitmentStart = job.recruitmentStartDate;
  if (recruitmentStart != null) {
    return DateTime(
      recruitmentStart.year,
      recruitmentStart.month,
      recruitmentStart.day,
    );
  }

  return null;
}

List<String> _schedulePreviewShiftTimes(JobPost job, DateTime? date) {
  final shiftTimes = workShiftRulesFromJob(job).map((rule) => rule.timeRange);

  final uniqueTimes = <String>[];
  for (final time in shiftTimes) {
    final trimmed = time.trim();
    if (trimmed.isNotEmpty && !uniqueTimes.contains(trimmed)) {
      uniqueTimes.add(trimmed);
    }
  }
  return uniqueTimes;
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
