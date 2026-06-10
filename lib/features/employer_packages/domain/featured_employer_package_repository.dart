import 'employer_package.dart';

abstract class FeaturedEmployerPackageRepository {
  Future<List<FeaturedEmployer>> getFeaturedEmployers();

  Future<List<EmployerPackagePlan>> getAvailablePackages();

  Future<EmployerPackageStatus?> getCurrentPackageStatus();

  Future<void> purchasePackage(EmployerPackageTier tier);
}
