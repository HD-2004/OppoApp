import '../domain/policy_document.dart';
import 'oppo_policy_source.dart';
import 'policy_document_parser.dart';

abstract class PolicyRepository {
  Future<PolicyDocument> loadPolicies();
}

class BundledPolicyRepository implements PolicyRepository {
  const BundledPolicyRepository({this.source = oppoPlatformPolicyText});

  final String source;

  @override
  Future<PolicyDocument> loadPolicies() async {
    return PolicyDocumentParser.parse(source);
  }
}
