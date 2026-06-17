import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

import '../domain/employer_package.dart';
import '../domain/featured_employer_package_repository.dart';

class ApiFeaturedEmployerPackageRepository
    implements FeaturedEmployerPackageRepository {
  ApiFeaturedEmployerPackageRepository({
    http.Client? client,
    this.baseUrl = _defaultBaseUrl,
  }) : _client = client ?? http.Client(),
       assert(baseUrl != '');

  static const _defaultBaseUrl =
      'https://p0nd7frlhg.execute-api.ap-southeast-1.amazonaws.com';

  final http.Client _client;
  final String baseUrl;

  void close() => _client.close();

  @override
  Future<List<FeaturedEmployer>> getFeaturedEmployers() async {
    final subscriptions = await _getList('/subscriptions');
    final now = DateTime.now();
    final employers = <String, FeaturedEmployer>{};

    for (final item in subscriptions) {
      final status = item['status']?.toString().toLowerCase();
      final approval = item['approvalStatus']?.toString().toLowerCase();
      final expiry = _date(
        item['expiryDateTime'] ?? item['expiryDate'] ?? item['expiresAt'],
      );
      if (status != 'active' ||
          (approval != null && approval != 'approved') ||
          (expiry != null && expiry.isBefore(now))) {
        continue;
      }

      final employerId = item['employerId']?.toString() ?? '';
      if (employerId.isEmpty) continue;
      final tier = _tier(item['packageName']?.toString());
      final current = employers[employerId];
      if (current != null && current.packageTier.index >= tier.index) {
        continue;
      }
      employers[employerId] = FeaturedEmployer(
        id: employerId,
        name: item['companyName']?.toString().trim().isNotEmpty == true
            ? item['companyName'].toString().trim()
            : 'Nhà tuyển dụng',
        logoUrl: item['companyLogo']?.toString() ?? item['logoUrl']?.toString(),
        packageTier: tier,
      );
    }

    final result = employers.values.toList();
    result.sort((a, b) => b.packageTier.index.compareTo(a.packageTier.index));
    return result;
  }

  @override
  Future<List<BannerAd>> getBanners() async {
    try {
      final list = await _getList('/packages?type=banners');
      return list.map(BannerAd.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<EmployerPackagePlan>> getAvailablePackages() async {
    final packages = await _getList('/packages');
    return packages
        .map((item) {
          final tier = _tier(item['packageName']?.toString());
          final rawFeatures = item['features'];
          final benefits = rawFeatures is List
              ? rawFeatures.map((value) => value.toString()).toList()
              : rawFeatures is Map && rawFeatures['vi'] is List
              ? (rawFeatures['vi'] as List)
                    .map((value) => value.toString())
                    .toList()
              : <String>[];
          final prices = item['prices'];
          final firstPrice = prices is List && prices.isNotEmpty
              ? prices.first
              : null;
          final amount = firstPrice is Map ? firstPrice['amount'] : null;
          return EmployerPackagePlan(
            id:
                item['packageId']?.toString() ??
                item['packageName']?.toString() ??
                tier.code,
            tier: tier,
            benefits: benefits,
            priceLabel: amount == null ? null : '${_money(amount)} VNĐ',
            description: _localizedText(item['subtitle']),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<EmployerPackageStatus?> getCurrentPackageStatus() async {
    final auth = await _authContext();
    final subscriptions = await _getList(
      '/subscriptions/employer/${Uri.encodeComponent(auth.userId)}',
    );
    final now = DateTime.now();
    EmployerPackageStatus? current;
    for (final item in subscriptions) {
      if (item['status']?.toString().toLowerCase() != 'active') continue;
      final activated = _date(item['purchaseDateTime'] ?? item['createdAt']);
      final expires = _date(item['expiryDateTime'] ?? item['expiryDate']);
      if (activated == null || expires == null || expires.isBefore(now)) {
        continue;
      }
      final candidate = EmployerPackageStatus(
        tier: _tier(item['packageName']?.toString()),
        activatedAt: activated,
        expiresAt: expires,
      );
      if (current == null || candidate.expiresAt.isAfter(current.expiresAt)) {
        current = candidate;
      }
    }
    return current;
  }

  @override
  Future<void> purchasePackage(EmployerPackageTier tier) async {
    final auth = await _authContext();
    final packages = await _getList('/packages');
    final package = packages.firstWhere(
      (item) => _tier(item['packageName']?.toString()) == tier,
      orElse: () => <String, dynamic>{},
    );
    if (package.isEmpty) {
      throw StateError('Không tìm thấy gói dịch vụ trên hệ thống.');
    }

    final prices = package['prices'];
    final firstPrice = prices is List && prices.isNotEmpty
        ? prices.first
        : null;
    final duration = firstPrice is Map
        ? firstPrice['duration']?.toString()
        : null;
    if (duration == null || duration.isEmpty) {
      throw StateError('Gói dịch vụ chưa có thời hạn sử dụng.');
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/subscriptions'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'employerId': auth.userId,
        'companyName': auth.displayName,
        'packageName': package['packageName'],
        'duration': duration,
        'paymentMethod': 'contact',
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = _decodeMap(response.body);
      throw StateError(
        body['message']?.toString() ?? 'Không thể đăng ký gói dịch vụ.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = _decodeMap(response.body);
      throw StateError(
        body['message']?.toString() ?? 'Không thể tải dữ liệu gói dịch vụ.',
      );
    }
    final decoded = jsonDecode(response.body);
    final raw = decoded is List
        ? decoded
        : decoded is Map
        ? decoded['data']
        : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<_PackageAuthContext> _authContext() async {
    final plugin = Amplify.Auth.getPlugin(AmplifyAuthCognito.pluginKey);
    final session = await plugin.fetchAuthSession();
    final userId =
        session.userPoolTokensResult.valueOrNull?.idToken.claims.subject;
    if (userId == null || userId.isEmpty) {
      throw StateError('Không tìm thấy phiên đăng nhập.');
    }

    var displayName = 'Nhà tuyển dụng';
    final attributes = await Amplify.Auth.fetchUserAttributes();
    for (final attribute in attributes) {
      if (attribute.userAttributeKey.key == 'name' &&
          attribute.value.trim().isNotEmpty) {
        displayName = attribute.value.trim();
        break;
      }
    }
    return _PackageAuthContext(userId: userId, displayName: displayName);
  }

  EmployerPackageTier _tier(String? packageName) {
    final value = packageName?.toLowerCase() ?? '';
    if (value.contains('top') ||
        value.contains('spotlight') ||
        value.contains('enterprise')) {
      return EmployerPackageTier.enterprise;
    }
    if (value.contains('hot') || value.contains('premium')) {
      return EmployerPackageTier.premium;
    }
    return EmployerPackageTier.basicBoost;
  }

  DateTime? _date(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String? _localizedText(dynamic value) {
    if (value is Map) {
      return value['vi']?.toString() ?? value['en']?.toString();
    }
    return value?.toString();
  }

  String _money(dynamic value) {
    final amount = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  Map<String, dynamic> _decodeMap(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }
}

class _PackageAuthContext {
  const _PackageAuthContext({required this.userId, required this.displayName});

  final String userId;
  final String displayName;
}
