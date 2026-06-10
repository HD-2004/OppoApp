import '../domain/employer_package.dart';
import '../domain/featured_employer_package_repository.dart';

class EmptyFeaturedEmployerPackageRepository
    implements FeaturedEmployerPackageRepository {
  @override
  Future<List<FeaturedEmployer>> getFeaturedEmployers() async {
    return const [];
  }

  @override
  Future<List<EmployerPackagePlan>> getAvailablePackages() async {
    return const [];
  }

  @override
  Future<EmployerPackageStatus?> getCurrentPackageStatus() async {
    return null;
  }

  @override
  Future<void> purchasePackage(EmployerPackageTier tier) {
    throw UnsupportedError('Featured employer package API is not configured.');
  }
}
