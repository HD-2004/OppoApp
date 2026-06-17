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
    this.linkUrl,
    this.order = 999.0,
    this.isActive = true,
  });

  final String bannerId;
  final String title;
  final String imageUrl;
  final String? linkUrl;
  final double order;
  final bool isActive;

  factory BannerAd.fromJson(Map<String, dynamic> json) {
    return BannerAd(
      bannerId: json['bannerId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      linkUrl: json['linkUrl']?.toString(),
      order: (json['order'] as num?)?.toDouble() ?? 999.0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

