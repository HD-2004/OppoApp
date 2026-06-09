import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/config/s3_asset_config.dart';

void main() {
  test('S3 asset catalog matches the web candidate banner order', () {
    expect(S3AssetConfig.logo, endsWith('/system/logo.png'));
    expect(S3AssetConfig.candidateBanners, [
      endsWith('/banner/seoul.jpg'),
      endsWith('/banner/unnamed1.jpg'),
      endsWith('/banner/unnamed.jpg'),
    ]);
  });
}
