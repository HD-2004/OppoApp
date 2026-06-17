import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/policy_repository.dart';
import '../domain/policy_document.dart';

final policyRepositoryProvider = Provider<PolicyRepository>((ref) {
  return const BundledPolicyRepository();
});

final policyDocumentProvider = FutureProvider<PolicyDocument>((ref) {
  return ref.watch(policyRepositoryProvider).loadPolicies();
});
