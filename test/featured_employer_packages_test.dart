import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/employer_packages/data/empty_featured_employer_package_repository.dart';
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

  test(
    'empty package repository returns no featured employers or package state',
    () async {
      final repository = EmptyFeaturedEmployerPackageRepository();

      expect(await repository.getFeaturedEmployers(), isEmpty);
      expect(await repository.getCurrentPackageStatus(), isNull);
      expect(await repository.getAvailablePackages(), isEmpty);
    },
  );
}
