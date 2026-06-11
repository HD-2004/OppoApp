import 'package:flutter/material.dart';

class CandidateIntentInput extends StatelessWidget {
  const CandidateIntentInput({
    super.key,
    this.avatarUrl,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
  });

  final String? avatarUrl;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final fieldColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF1F5F9);
    final avatarFallbackColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    const hintColor = Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _CandidateAvatar(
            avatarUrl: avatarUrl,
            backgroundColor: avatarFallbackColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                onTap: onTap,
                textInputAction: TextInputAction.search,
                maxLines: 1,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Bạn muốn tìm công việc như thế nào?',
                  hintStyle: const TextStyle(color: hintColor, fontSize: 14),
                  filled: true,
                  fillColor: fieldColor,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.65),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateAvatar extends StatelessWidget {
  const _CandidateAvatar({
    required this.avatarUrl,
    required this.backgroundColor,
  });

  final String? avatarUrl;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final imageUrl = avatarUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: hasImage
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, _, _) => const _AvatarFallbackIcon(),
            )
          : const _AvatarFallbackIcon(),
    );
  }
}

class _AvatarFallbackIcon extends StatelessWidget {
  const _AvatarFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.person_outline_rounded,
      color: Color(0xFF64748B),
      size: 25,
    );
  }
}
