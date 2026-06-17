class PolicyDocument {
  const PolicyDocument({required this.policies, this.version, this.updatedAt});

  final String? version;
  final String? updatedAt;
  final List<PolicyItem> policies;

  PolicyItem? findBySlug(String slug) {
    for (final policy in policies) {
      if (policy.slug == slug) return policy;
    }
    return null;
  }
}

class PolicyItem {
  const PolicyItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.content,
    this.appliesTo,
    this.effectiveDate,
  });

  final String id;
  final String slug;
  final String title;
  final String content;
  final String? appliesTo;
  final String? effectiveDate;
}
