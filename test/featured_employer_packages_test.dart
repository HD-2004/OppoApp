import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/employer_packages/data/api_featured_employer_package_repository.dart';
import 'package:oppo_temp_jobs/features/employer_packages/domain/employer_package.dart';

void main() {
  test('package tiers expose product labels and badge labels', () {
    expect(EmployerPackageTier.basicBoost.title, 'Basic Boost');
    expect(EmployerPackageTier.basicBoost.badgeLabel, '⭐ Basic Boost');
    expect(EmployerPackageTier.premium.title, 'Premium');
    expect(EmployerPackageTier.premium.badgeLabel, '🚀 Premium');
    expect(EmployerPackageTier.enterprise.title, 'Enterprise');
    expect(EmployerPackageTier.enterprise.badgeLabel, '👑 Enterprise');
  });

  test('package repository maps shared API data', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/subscriptions') {
        return http.Response.bytes(
          utf8.encode('''
            [{
              "employerId": "employer-1",
              "companyName": "Op Po Cafe",
              "bannerImageUrl": "https://example.test/banner.jpg",
              "packageName": "Top Spotlight",
              "status": "active",
              "approvalStatus": "approved",
              "expiryDateTime": "2099-01-01T00:00:00Z"
            }]
            '''),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/packages') {
        return http.Response.bytes(
          utf8.encode('''
            {
              "success": true,
              "data": [{
                "packageId": "hot-search",
                "packageName": "Hot Search",
                "subtitle": {"vi": "Hiển thị nổi bật"},
                "features": {"vi": ["Ưu tiên tìm kiếm"]},
                "prices": [{"duration": "7 ngày", "amount": 100000}]
              }]
            }
            '''),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 404);
    });
    final repository = ApiFeaturedEmployerPackageRepository(
      client: client,
      baseUrl: 'https://example.test',
    );

    final employers = await repository.getFeaturedEmployers();
    final plans = await repository.getAvailablePackages();

    expect(employers.single.name, 'Op Po Cafe');
    expect(employers.single.bannerImageUrl, 'https://example.test/banner.jpg');
    expect(employers.single.packageTier, EmployerPackageTier.enterprise);
    expect(plans.single.tier, EmployerPackageTier.premium);
    expect(plans.single.benefits, ['Ưu tiên tìm kiếm']);
  });

  test('package repository only returns app-sized banners', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/packages' &&
          request.url.queryParameters['type'] == 'banners') {
        return http.Response.bytes(
          utf8.encode('''
            {
              "success": true,
              "data": [
                {
                  "bannerId": "valid-banner",
                  "title": "Valid banner",
                  "imageUrl": "https://example.test/valid.jpg",
                  "imageWidth": 1600,
                  "imageHeight": 517
                },
                {
                  "bannerId": "wrong-banner",
                  "title": "Wrong banner",
                  "imageUrl": "https://example.test/wrong.jpg",
                  "imageWidth": 720,
                  "imageHeight": 1280
                },
                {
                  "bannerId": "missing-size",
                  "title": "Missing size",
                  "imageUrl": "https://example.test/missing.jpg"
                }
              ]
            }
            '''),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 404);
    });
    final repository = ApiFeaturedEmployerPackageRepository(
      client: client,
      baseUrl: 'https://example.test',
    );

    final banners = await repository.getBanners();

    expect(banners, hasLength(1));
    expect(banners.single.bannerId, 'valid-banner');
    expect(banners.single.hasValidAppImageSize, isTrue);
    expect(
      BannerAd.invalidAppImageSizeMessage,
      'poster này của bạn không đúng với kích thước bên app vui lòng chọn đúng kích thước poster là 1600 x 517. Chỉ poster đúng kích thước 1600 x 517 mới được đăng.',
    );
  });
}
