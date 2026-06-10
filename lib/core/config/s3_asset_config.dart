class S3AssetConfig {
  const S3AssetConfig._();

  static const baseUrl = String.fromEnvironment(
    'S3_ASSETS_BASE_URL',
    defaultValue:
        'https://opporeview-cv-storage.s3.ap-southeast-1.amazonaws.com',
  );

  static const logo = '$baseUrl/system/logo.png';

  static const bannerSeoul = '$baseUrl/banner/seoul.jpg';
  static const bannerUnnamed1 = '$baseUrl/banner/unnamed1.jpg';
  static const bannerUnnamed = '$baseUrl/banner/unnamed.jpg';

  static const posterPhucLocTho = '$baseUrl/poster/phucloctho.jpg';

  static List<String> get candidateBanners => <String>[
    bannerSeoul,
    bannerUnnamed1,
    bannerUnnamed,
  ];
}
