import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_featured_employer_package_repository.dart';
import '../domain/employer_package.dart';
import '../domain/featured_employer_package_repository.dart';

final featuredEmployerPackageRepositoryProvider =
    Provider<FeaturedEmployerPackageRepository>((ref) {
      final repository = ApiFeaturedEmployerPackageRepository();
      ref.onDispose(repository.close);
      return repository;
    });

final featuredEmployersProvider =
    FutureProvider.autoDispose<List<FeaturedEmployer>>((ref) async {
      final repository = ref.watch(featuredEmployerPackageRepositoryProvider);
      return repository.getFeaturedEmployers();
    });

final packagePlansProvider =
    FutureProvider.autoDispose<List<EmployerPackagePlan>>((ref) async {
      final repository = ref.watch(featuredEmployerPackageRepositoryProvider);
      return repository.getAvailablePackages();
    });

final currentPackageStatusProvider =
    FutureProvider.autoDispose<EmployerPackageStatus?>((ref) async {
      final repository = ref.watch(featuredEmployerPackageRepositoryProvider);
      return repository.getCurrentPackageStatus();
    });

final packagePurchaseControllerProvider =
    AsyncNotifierProvider<PackagePurchaseController, void>(
      PackagePurchaseController.new,
    );

class PackagePurchaseController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> purchase(EmployerPackageTier tier) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(featuredEmployerPackageRepositoryProvider);
      await repository.purchasePackage(tier);
      ref.invalidate(currentPackageStatusProvider);
      ref.invalidate(featuredEmployersProvider);
      ref.invalidate(packagePlansProvider);
    });
  }
}
