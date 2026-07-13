import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../policies/application/policy_providers.dart';
import '../../policies/domain/policy_document.dart';

class PolicyTermsScreen extends ConsumerWidget {
  const PolicyTermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final policies = ref.watch(policyDocumentProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(title: Text(l10n.text('policyTerms'))),
      body: SafeArea(
        child: policies.when(
          data: (document) {
            if (document.policies.isEmpty) {
              return const _PolicyStateMessage(
                message: 'Chưa có chính sách được cấu hình',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: document.policies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final policy = document.policies[index];
                return _PolicyCard(
                  policy: policy,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PolicyDetailScreen(
                        policy: policy,
                        version: document.version,
                        updatedAt: document.updatedAt,
                      ),
                    ),
                  ),
                );
              },
            );
          },
          error: (error, _) => _PolicyStateMessage(message: error.toString()),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class PolicyDetailScreen extends ConsumerWidget {
  const PolicyDetailScreen({
    super.key,
    this.slug,
    this.policy,
    this.version,
    this.updatedAt,
  });

  final String? slug;
  final PolicyItem? policy;
  final String? version;
  final String? updatedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (policy != null) {
      return _PolicyDetailScaffold(
        policy: policy!,
        version: version,
        updatedAt: updatedAt,
      );
    }

    final policies = ref.watch(policyDocumentProvider);
    return policies.when(
      data: (document) {
        final resolved = slug == null ? null : document.findBySlug(slug!);
        if (resolved == null) {
          return const Scaffold(
            body: SafeArea(
              child: _PolicyStateMessage(
                message: 'Chưa có chính sách được cấu hình',
              ),
            ),
          );
        }
        return _PolicyDetailScaffold(
          policy: resolved,
          version: document.version,
          updatedAt: document.updatedAt,
        );
      },
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Chính sách')),
        body: SafeArea(child: _PolicyStateMessage(message: error.toString())),
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Chính sách')),
        body: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class PolicyInlineLinks extends ConsumerWidget {
  const PolicyInlineLinks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policies = ref.watch(policyDocumentProvider).asData?.value.policies;
    if (policies == null || policies.isEmpty) {
      return const SizedBox.shrink();
    }

    final terms = _findPolicy(policies, 'dieu-khoan-su-dung-chung');
    final privacy = _findPolicy(policies, 'bao-mat-du-lieu-ca-nhan');
    final links = [
      if (terms != null)
        _PolicyLinkData(label: 'Điều khoản sử dụng', policy: terms),
      if (privacy != null)
        _PolicyLinkData(label: 'Chính sách bảo mật', policy: privacy),
    ];
    if (links.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < links.length; i++) ...[
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PolicyDetailScreen(slug: links[i].policy.slug),
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.88),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              links[i].label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (i < links.length - 1)
            Text(
              '•',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
        ],
      ],
    );
  }
}

PolicyItem? _findPolicy(List<PolicyItem> policies, String slug) {
  for (final policy in policies) {
    if (policy.slug == slug) return policy;
  }
  return null;
}

class _PolicyDetailScaffold extends StatelessWidget {
  const _PolicyDetailScaffold({
    required this.policy,
    required this.version,
    required this.updatedAt,
  });

  final PolicyItem policy;
  final String? version;
  final String? updatedAt;

  @override
  Widget build(BuildContext context) {
    final content = policy.content.trim();
    final displayContent = _formatPolicyDetailContent(content);
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(title: const Text('Chính sách')),
      body: SafeArea(
        child: content.isEmpty
            ? const _PolicyStateMessage(
                message: 'Nội dung chính sách chưa được cấu hình',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    policy.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimaryFor(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PolicyMetaWrap(
                    version: version,
                    updatedAt: updatedAt,
                    effectiveDate: policy.effectiveDate,
                  ),
                  const SizedBox(height: 20),
                  SelectableText.rich(
                    _buildPolicyDetailTextSpan(context, displayContent),
                  ),
                ],
              ),
      ),
    );
  }
}

String _formatPolicyDetailContent(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  return _joinPolicyDetailLines(_collapsePolicyTables(lines));
}

List<String> _collapsePolicyTables(List<String> lines) {
  final collapsed = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (_isProcessTableHeader(lines, i)) {
      i += 3;
      while (i + 2 < lines.length && _isPlainNumber(lines[i])) {
        final step = lines[i].replaceAll('.', '');
        final action = lines[i + 1];
        final timing = lines[i + 2];
        collapsed.add('$step. $action - $timing');
        i += 3;
      }
      i--;
      continue;
    }
    collapsed.add(lines[i]);
  }
  return collapsed;
}

bool _isProcessTableHeader(List<String> lines, int index) {
  return index + 2 < lines.length &&
      lines[index].toLowerCase() == 'bước' &&
      lines[index + 1].toLowerCase() == 'hành động' &&
      lines[index + 2].toLowerCase() == 'thời gian xử lý';
}

bool _isPlainNumber(String line) {
  return RegExp(r'^\d+\.?$').hasMatch(line.trim());
}

String _joinPolicyDetailLines(List<String> lines) {
  if (lines.isEmpty) return '';
  final buffer = StringBuffer(lines.first);
  for (var i = 1; i < lines.length; i++) {
    buffer
      ..write(_shouldCompactPolicyLine(lines[i - 1], lines[i]) ? '\n' : '\n\n')
      ..write(lines[i]);
  }
  return buffer.toString();
}

bool _shouldCompactPolicyLine(String previous, String current) {
  return _isCompactProcessItem(previous) && _isCompactProcessItem(current);
}

bool _isCompactProcessItem(String line) {
  return RegExp(r'^\d+\.\s+.+\s-\s.+$').hasMatch(line.trim());
}

TextSpan _buildPolicyDetailTextSpan(BuildContext context, String content) {
  final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
    height: 1.55,
    color: AppColors.textSecondaryFor(context),
  );
  final boldStyle = baseStyle?.copyWith(
    color: AppColors.textPrimaryFor(context),
    fontWeight: FontWeight.w800,
  );
  final lines = content.split('\n\n');
  return TextSpan(
    style: baseStyle,
    children: [
      for (var i = 0; i < lines.length; i++) ...[
        TextSpan(
          text: lines[i],
          style: _isPolicyEmphasisLine(lines[i]) ? boldStyle : baseStyle,
        ),
        if (i < lines.length - 1) const TextSpan(text: '\n\n'),
      ],
    ],
  );
}

bool _isPolicyEmphasisLine(String value) {
  final line = value.trim();
  if (line.isEmpty) return false;
  if (RegExp(r'^CHÍNH SÁCH\s+\d{2}:?$', caseSensitive: false).hasMatch(line)) {
    return true;
  }
  if (RegExp(r'^\d+(?:\.\d+)*\.?\s+\S').hasMatch(line)) {
    return true;
  }
  if (_isUppercaseHeading(line)) {
    return true;
  }
  final labelMatch = RegExp(r'^[^:]{2,48}:').firstMatch(line);
  return labelMatch != null;
}

bool _isUppercaseHeading(String line) {
  return line.length >= 4 &&
      line != line.toLowerCase() &&
      line == line.toUpperCase();
}

class _PolicyMetaWrap extends StatelessWidget {
  const _PolicyMetaWrap({
    required this.version,
    required this.updatedAt,
    required this.effectiveDate,
  });

  final String? version;
  final String? updatedAt;
  final String? effectiveDate;

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (version != null && version!.trim().isNotEmpty) version!.trim(),
      if (updatedAt != null && updatedAt!.trim().isNotEmpty) updatedAt!.trim(),
      if (effectiveDate != null && effectiveDate!.trim().isNotEmpty)
        'Hiệu lực: ${effectiveDate!.trim()}',
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (chip) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.softPrimaryFor(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderFor(context)),
              ),
              child: Text(
                chip,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimaryFor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.policy, required this.onTap});

  final PolicyItem policy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.borderFor(context)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.description_outlined,
                color: AppColors.iconFor(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      policy.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryFor(context),
                      ),
                    ),
                    if (policy.appliesTo != null &&
                        policy.appliesTo!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Áp dụng cho: ${policy.appliesTo}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMutedFor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMutedFor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyStateMessage extends StatelessWidget {
  const _PolicyStateMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textMutedFor(context),
          ),
        ),
      ),
    );
  }
}

class _PolicyLinkData {
  const _PolicyLinkData({required this.label, required this.policy});

  final String label;
  final PolicyItem policy;
}
