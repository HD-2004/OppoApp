import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/config/s3_asset_config.dart';
import '../../../../core/formatters/app_date_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../candidate/domain/job_post.dart';
import '../../../candidate/domain/job_work_schedule.dart';
import '../../../employer_packages/domain/employer_package.dart';
import '../../../messaging/domain/candidate_application.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.displayName,
    required this.onNotificationTap,
    required this.onChatTap,
    required this.notificationCount,
    required this.chatCount,
  });

  final String displayName;
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

class PopularJobsSection extends StatelessWidget {
  const PopularJobsSection({
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

  static const double _jobCardHeight = 430;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Công việc phổ biến nhất',
      trailing: jobs.isEmpty ? null : _SeeAllButton(onPressed: onSeeAll),
      child: Builder(
        builder: (context) {
          if (isLoading && jobs.isEmpty) {
            return const _HorizontalSkeleton(height: _jobCardHeight);
          }
          if (hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: EmptyState(
                icon: Icons.trending_up_rounded,
                title: 'Chưa tải được công việc phổ biến',
                message: 'Bạn thử tải lại danh sách công việc phổ biến.',
                actionLabel: 'Thử lại',
                onAction: onRetry,
              ),
            );
          }
          if (jobs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: EmptyState(
                title: 'Tạm thời chưa có công việc phổ biến.',
                message: 'Hãy quay lại sau khi có thêm tin tuyển dụng mới.',
                illustrationAsset: 'img/intro.png',
              ),
            );
          }

          return SizedBox(
            height: _jobCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, index) {
                final job = jobs[index];
                return JobCard(
                  job: job,
                  onTap: () => onJobTap(job),
                  onApply: () => onApply(job),
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
    required this.onCompanyTap,
  });

  final List<CompanyRankItem> companies;
  final bool isLoading;
  final VoidCallback onSeeAll;
  final ValueChanged<CompanyRankItem> onCompanyTap;

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
                      CompanyRankCard(
                        item: companies[index],
                        onTap: () => onCompanyTap(companies[index]),
                      ),
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

class RecentApplicationsSection extends StatelessWidget {
  const RecentApplicationsSection({
    super.key,
    required this.applications,
    required this.isLoading,
    required this.onApplicationTap,
  });

  final List<CandidateApplication> applications;
  final bool isLoading;
  final ValueChanged<CandidateApplication> onApplicationTap;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && applications.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RecentApplicationsHeader(),
          const SizedBox(height: 16),
          if (isLoading)
            const _SkeletonBox(height: 304, radius: 16)
          else
            Column(
              children: [
                for (var index = 0; index < applications.length; index++) ...[
                  _RecentApplicationCard(
                    application: applications[index],
                    isHighlighted: index == 0,
                    onTap: () => onApplicationTap(applications[index]),
                  ),
                  if (index < applications.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _RecentApplicationsHeader extends StatelessWidget {
  const _RecentApplicationsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(
              Icons.article_outlined,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đơn Ứng Tuyển Của Bạn Gần Đây',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, thickness: 1.4, color: AppColors.borderFor(context)),
      ],
    );
  }
}

class _RecentApplicationCard extends StatelessWidget {
  const _RecentApplicationCard({
    required this.application,
    required this.isHighlighted,
    required this.onTap,
  });

  final CandidateApplication application;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isHighlighted
        ? AppColors.primary
        : AppColors.borderFor(context);
    final borderWidth = isHighlighted ? 1.8 : 1.1;
    final timeLabel = postedTimeLabel(application.updatedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: isHighlighted ? 0.08 : 0.03,
                ),
                blurRadius: isHighlighted ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.jobTitle.trim().isEmpty
                          ? 'Vị trí ứng tuyển'
                          : application.jobTitle.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        height: 1.22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application.employerName.trim().isEmpty
                          ? 'Nhà tuyển dụng'
                          : application.employerName.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondaryFor(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.28,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (timeLabel.isNotEmpty)
                          _RecentApplicationMeta(
                            icon: Icons.schedule_rounded,
                            label: timeLabel,
                          ),
                        const _RecentApplicationMeta(
                          icon: Icons.visibility_outlined,
                          label: 'Xem chi tiết',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _ApplicationBadge(
                    label: 'Chưa Xem',
                    color: Color(0xFFFF9800),
                    backgroundColor: Color(0xFFFFF7E6),
                    borderColor: Color(0xFFFFD77A),
                  ),
                  const SizedBox(height: 10),
                  _ApplicationBadge(
                    label: _applicationTypeLabel(application),
                    color: AppColors.primary,
                    backgroundColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFB8CEFF),
                    isCompact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentApplicationMeta extends StatelessWidget {
  const _RecentApplicationMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondaryFor(context)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplicationBadge extends StatelessWidget {
  const _ApplicationBadge({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    this.isCompact = false,
  });

  final String label;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 11 : 16,
        vertical: isCompact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isCompact ? 7 : 9,
            height: isCompact ? 7 : 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: isCompact ? 12.5 : 14,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

String _applicationTypeLabel(CandidateApplication application) {
  final normalized = application.jobType.trim().toLowerCase();
  if (normalized.contains('urgent') || normalized.contains('quick')) {
    return 'Tuyển Gấp';
  }
  return 'Tiêu Chuẩn';
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
            message,
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
  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final companyName = companyNameOf(job);
    final salaryLabel = publicOrHidden(job.salary);
    final locationLabel = publicOrHidden(job.location);
    final workDaysLabel = displayWorkShiftDays(job);
    final scheduleLabel = scheduleOf(job);
    final deadlineLabel = job.recruitmentEndDate == null
        ? ''
        : AppDateFormatter.formatVietnameseDate(job.recruitmentEndDate!);
    final visibleTags = job.tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .take(3)
        .toList(growable: false);
    final isUrgent = job.isQuickJob || job.jobType == JobPostType.urgent;

    return SizedBox(
      width: 328,
      child: Material(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.borderFor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LogoBox(
                      name: companyName,
                      imageUrl: job.employerAvatarUrl,
                      size: 52,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title.trim().isEmpty
                                ? 'Tin tuyển dụng'
                                : job.title.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimaryFor(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              height: 1.14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMutedFor(context),
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              if (locationLabel.isNotEmpty)
                                _InlineMeta(
                                  icon: Icons.location_on_outlined,
                                  label: locationLabel,
                                ),
                              _InlineMeta(
                                icon: Icons.work_outline_rounded,
                                label: _jobTypeShortLabel(job.jobType),
                              ),
                              if (job.views > 0)
                                _InlineMeta(
                                  icon: Icons.visibility_outlined,
                                  label: '${job.views} lượt xem',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ReferenceStatusBadge(isUrgent: isUrgent),
                    for (final tag in visibleTags) _ReferenceTag(label: tag),
                  ],
                ),
                if (salaryLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      'Thu nhập: $salaryLabel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
                if (workDaysLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ReferenceDetailLine(
                    icon: Icons.event_available_outlined,
                    label: 'Ngày làm: $workDaysLabel',
                  ),
                ],
                if (scheduleLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ReferenceDetailLine(
                    icon: Icons.access_time_rounded,
                    label: 'Thời gian: $scheduleLabel',
                  ),
                ],
                if (deadlineLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _ReferenceDetailLine(
                    icon: Icons.calendar_today_outlined,
                    label: 'Hạn nộp: $deadlineLabel',
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Text(
                    'Vị trí này có thể phù hợp với bạn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onApply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      minimumSize: const Size.fromHeight(38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Ứng tuyển'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceStatusBadge extends StatelessWidget {
  const _ReferenceStatusBadge({required this.isUrgent});

  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final color = isUrgent ? const Color(0xFFF97316) : const Color(0xFF2454C6);
    final background = isUrgent
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFEFF6FF);
    final border = isUrgent ? const Color(0xFFFED7AA) : const Color(0xFFAEC5FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 6),
          Text(
            isUrgent ? 'Tuyển gấp' : 'Tiêu chuẩn',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width < 380 ? 118.0 : 160.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMutedFor(context)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textMutedFor(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceTag extends StatelessWidget {
  const _ReferenceTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textPrimaryFor(context),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _ReferenceDetailLine extends StatelessWidget {
  const _ReferenceDetailLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.textMutedFor(context)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMutedFor(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.32,
            ),
          ),
        ),
      ],
    );
  }
}

class CompanyRankCard extends StatelessWidget {
  const CompanyRankCard({super.key, required this.item, required this.onTap});

  final CompanyRankItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
        ),
      ),
    );
  }
}

class CompanyRankItem {
  const CompanyRankItem({
    required this.rank,
    required this.name,
    required this.activeJobCount,
    this.employerId = '',
    this.logoUrl,
    this.jobs = const [],
  });

  final int rank;
  final String name;
  final int activeJobCount;
  final String employerId;
  final String? logoUrl;
  final List<JobPost> jobs;
}

class EmployerInfoSheet extends StatelessWidget {
  const EmployerInfoSheet({
    super.key,
    required this.item,
    required this.onJobTap,
  });

  final CompanyRankItem item;
  final ValueChanged<JobPost> onJobTap;

  @override
  Widget build(BuildContext context) {
    final jobs = item.jobs.take(5).toList(growable: false);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.84;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderFor(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Thông tin nhà tuyển dụng',
                    style: TextStyle(
                      color: AppColors.textPrimaryFor(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      LogoBox(
                        name: item.name,
                        imageUrl: item.logoUrl,
                        size: 64,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimaryFor(context),
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                height: 1.18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item.activeJobCount} việc đang tuyển',
                              style: TextStyle(
                                color: AppColors.textSecondaryFor(context),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Tin đang tuyển',
                    style: TextStyle(
                      color: AppColors.textPrimaryFor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (jobs.isEmpty)
                    Text(
                      'Chưa có tin tuyển dụng khả dụng.',
                      style: TextStyle(
                        color: AppColors.textSecondaryFor(context),
                        fontSize: 14,
                      ),
                    )
                  else
                    for (var index = 0; index < jobs.length; index++) ...[
                      _EmployerInfoJobTile(
                        job: jobs[index],
                        onTap: () => onJobTap(jobs[index]),
                      ),
                      if (index < jobs.length - 1) const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployerInfoJobTile extends StatelessWidget {
  const _EmployerInfoJobTile({required this.job, required this.onTap});

  final JobPost job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final location = job.location.trim();
    final schedule = scheduleOf(job);
    final salary = publicOrHidden(job.salary);

    return Material(
      color: AppColors.cardBackground(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderFor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.title.trim().isEmpty ? 'Tin tuyển dụng' : job.title.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  if (location.isNotEmpty)
                    _EmployerInfoMeta(
                      icon: Icons.location_on_outlined,
                      label: location,
                    ),
                  if (schedule.isNotEmpty)
                    _EmployerInfoMeta(
                      icon: Icons.schedule_rounded,
                      label: schedule,
                    ),
                  if (salary.isNotEmpty)
                    _EmployerInfoMeta(
                      icon: Icons.payments_outlined,
                      label: salary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployerInfoMeta extends StatelessWidget {
  const _EmployerInfoMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 72;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: availableWidth < 160 ? 160 : availableWidth,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textMutedFor(context)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondaryFor(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LogoBox extends StatelessWidget {
  const LogoBox({super.key, required this.name, this.imageUrl, this.size = 58});

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = _resolvedEmployerLogoUrl(name, imageUrl);
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
  return 'Nhà tuyển dụng';
}

String scheduleOf(JobPost job) {
  return displayWorkShiftTime(job);
}

String _jobTypeShortLabel(JobPostType type) {
  return switch (type) {
    JobPostType.urgent => 'Tuyển gấp',
    JobPostType.partTime => 'Part-time',
    JobPostType.fullTime => 'Full-time',
  };
}

String? _resolvedEmployerLogoUrl(String name, String? imageUrl) {
  final image = imageUrl?.trim();
  if (image != null && image.isNotEmpty) return image;

  final normalizedName = name.toLowerCase();
  if (normalizedName.contains('katinat')) {
    return '${S3AssetConfig.baseUrl}/system/katinatlogo.jpg';
  }
  return null;
}

String publicOrHidden(String value) {
  return value.trim();
}

String postedTimeLabel(DateTime postedAt) {
  if (postedAt.millisecondsSinceEpoch == 0) return '';
  final diff = DateTime.now().difference(postedAt);
  if (diff.isNegative || diff.inMinutes < 1) return 'Vừa đăng';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  return '${diff.inDays} ngày trước';
}
