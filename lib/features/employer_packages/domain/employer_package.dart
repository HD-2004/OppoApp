enum EmployerPackageTier {
  basicBoost,
  premium,
  enterprise;

  String get title {
    return switch (this) {
      EmployerPackageTier.basicBoost => 'Basic Boost',
      EmployerPackageTier.premium => 'Premium',
      EmployerPackageTier.enterprise => 'Enterprise',
    };
  }

  String get badgeLabel {
    return switch (this) {
      EmployerPackageTier.basicBoost => '⭐ Basic Boost',
      EmployerPackageTier.premium => '🚀 Premium',
      EmployerPackageTier.enterprise => '👑 Enterprise',
    };
  }

  String get code {
    return switch (this) {
      EmployerPackageTier.basicBoost => 'BASIC_BOOST',
      EmployerPackageTier.premium => 'PREMIUM',
      EmployerPackageTier.enterprise => 'ENTERPRISE',
    };
  }

  static EmployerPackageTier? fromBackend(String? value) {
    return switch (value?.trim().toUpperCase()) {
      'BASIC_BOOST' ||
      'BASICBOOST' ||
      'BASIC' => EmployerPackageTier.basicBoost,
      'PREMIUM' => EmployerPackageTier.premium,
      'ENTERPRISE' => EmployerPackageTier.enterprise,
      _ => null,
    };
  }
}

class EmployerPackagePlan {
  const EmployerPackagePlan({
    required this.id,
    required this.tier,
    required this.benefits,
    this.priceLabel,
    this.description,
  });

  final String id;
  final EmployerPackageTier tier;
  final List<String> benefits;
  final String? priceLabel;
  final String? description;
}

class EmployerPackageStatus {
  const EmployerPackageStatus({
    required this.tier,
    required this.activatedAt,
    required this.expiresAt,
  });

  final EmployerPackageTier tier;
  final DateTime activatedAt;
  final DateTime expiresAt;

  int remainingDays(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    return expiryDate.difference(today).inDays.clamp(0, 9999);
  }

  double progress(DateTime now) {
    final total = expiresAt.difference(activatedAt).inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(activatedAt).inSeconds.clamp(0, total);
    return elapsed / total;
  }
}

class FeaturedEmployer {
  const FeaturedEmployer({
    required this.id,
    required this.name,
    required this.packageTier,
    this.logoUrl,
    this.bannerImageUrl,
    this.rating,
    this.activeJobCount,
    this.distanceLabel,
  });

  final String id;
  final String name;
  final EmployerPackageTier packageTier;
  final String? logoUrl;
  final String? bannerImageUrl;
  final double? rating;
  final int? activeJobCount;
  final String? distanceLabel;
}

class BannerAd {
  const BannerAd({
    required this.bannerId,
    required this.title,
    required this.imageUrl,
    this.imageWidth,
    this.imageHeight,
    this.linkUrl,
    this.jobId,
    this.employerId,
    this.order = 999.0,
    this.isActive = true,
  });

  static const requiredImageWidth = 1600;
  static const requiredImageHeight = 517;
  static const invalidAppImageSizeMessage =
      'poster này của bạn không đúng với kích thước bên app vui lòng chọn đúng kích thước poster là 1600 x 517. Chỉ poster đúng kích thước 1600 x 517 mới được đăng.';

  final String bannerId;
  final String title;
  final String imageUrl;
  final int? imageWidth;
  final int? imageHeight;
  final String? linkUrl;

  /// Id of the job post this banner promotes. Populated by the employer/admin
  /// when the package banner is created. Null when the banner is not linked to
  /// a specific job.
  final String? jobId;

  /// Id of the employer that purchased the banner package.
  final String? employerId;
  final double order;
  final bool isActive;

  /// Whether this banner points to a concrete job post the app can open.
  bool get hasJobLink => (jobId?.trim().isNotEmpty ?? false);

  /// Only banners exported at the exact app slot size may appear in app.
  bool get hasValidAppImageSize =>
      imageWidth == requiredImageWidth && imageHeight == requiredImageHeight;

  factory BannerAd.fromJson(Map<String, dynamic> json) {
    String? firstNonEmpty(List<String> keys) {
      for (final key in keys) {
        final value = json[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    int? firstInt(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        final parsed = int.tryParse(value?.toString().trim() ?? '');
        if (parsed != null) return parsed;
      }
      return null;
    }

    return BannerAd(
      bannerId: json['bannerId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      imageWidth: firstInt([
        'imageWidth',
        'bannerWidth',
        'posterWidth',
        'width',
      ]),
      imageHeight: firstInt([
        'imageHeight',
        'bannerHeight',
        'posterHeight',
        'height',
      ]),
      linkUrl: json['linkUrl']?.toString(),
      // Read whatever linking key the backend provides — never fabricated.
      jobId: firstNonEmpty([
        'jobId',
        'jobPostId',
        'postId',
        'relatedJobId',
        'targetJobId',
      ]),
      employerId: firstNonEmpty(['employerId', 'companyId', 'ownerId']),
      order: (json['order'] as num?)?.toDouble() ?? 999.0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
