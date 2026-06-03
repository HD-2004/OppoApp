import 'package:flutter/material.dart';

/// "Danh mục phổ biến" — dạng Instagram Stories:
/// Hàng ngang scroll, mỗi item là circle có viền gradient + ảnh (từ S3 khi có)
/// + label + count bên dưới.
///
/// TODO: Khi backend bổ sung field `category.imageUrl` (S3 URL) thì truyền vào
/// [imageUrl] của mỗi category. Hiện tại fallback về placeholder emoji + màu.
class SearchCategoryGrid extends StatelessWidget {
  const SearchCategoryGrid({
    super.key,
    required this.categories,
    required this.onCategoryTap,
    this.selectedCategory = '',
  });

  final List<({String label, int count, String emoji, String? imageUrl})>
  categories;
  final ValueChanged<String> onCategoryTap;
  final String selectedCategory;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Danh mục phổ biến',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final cat = categories[i];
              return _StoryItem(
                label: cat.label,
                count: cat.count,
                emoji: cat.emoji,
                imageUrl: cat.imageUrl,
                isSelected: cat.label == selectedCategory,
                onTap: () => onCategoryTap(cat.label),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Gradient palette ──────────────────────────────────────────────────────────

const _storyGradients = [
  // Instagram-style gradients
  [Color(0xFFF09433), Color(0xFFE6683C), Color(0xFFDC2743), Color(0xFFCC2366)],
  [Color(0xFF405DE6), Color(0xFF5851DB), Color(0xFF833AB4)],
  [Color(0xFF12C2E9), Color(0xFFC471ED), Color(0xFFF64F59)],
  [Color(0xFFf7971e), Color(0xFFffd200)],
  [Color(0xFF11998e), Color(0xFF38ef7d)],
  [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
  [Color(0xFFe52d27), Color(0xFFb31217)],
  [Color(0xFF1D976C), Color(0xFF93F9B9)],
];

List<Color> _gradientFor(String label) {
  final idx = label.hashCode.abs() % _storyGradients.length;
  return _storyGradients[idx];
}

Color _bgColorFor(String label) {
  final colors = _gradientFor(label);
  return colors[0].withValues(alpha: 0.15);
}

// ── Story item ────────────────────────────────────────────────────────────────

class _StoryItem extends StatelessWidget {
  const _StoryItem({
    required this.label,
    required this.count,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
    this.imageUrl,
  });

  final String label;
  final int count;
  final String emoji;
  final String? imageUrl;
  final bool isSelected;
  final VoidCallback onTap;

  static const double _outerSize = 70;
  static const double _borderWidth = 2.5;
  static const double _gapWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final gradColors = _gradientFor(label);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Outer ring (gradient or grey if selected) ──────────────
            Container(
              width: _outerSize,
              height: _outerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? null
                    : LinearGradient(
                        colors: gradColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isSelected ? const Color(0xFFD1D5DB) : null,
              ),
              // ── White gap between ring and image ──────────────────────
              child: Padding(
                padding: EdgeInsets.all(_borderWidth + _gapWidth),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: _CircleContent(
                      imageUrl: imageUrl,
                      emoji: emoji,
                      label: label,
                      bgColor: _bgColorFor(label),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 5),

            // ── Label ─────────────────────────────────────────────────
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Count ─────────────────────────────────────────────────
            Text(
              '$count+ ca',
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Circle content: ảnh S3 nếu có, fallback emoji placeholder ────────────────

class _CircleContent extends StatelessWidget {
  const _CircleContent({
    required this.imageUrl,
    required this.emoji,
    required this.label,
    required this.bgColor,
  });

  final String? imageUrl;
  final String emoji;
  final String label;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) =>
            _Placeholder(emoji: emoji, bgColor: bgColor),
      );
    }
    return _Placeholder(emoji: emoji, bgColor: bgColor);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.emoji, required this.bgColor});

  final String emoji;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
    );
  }
}
