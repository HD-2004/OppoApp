import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';

import '../pages/search_page.dart';

/// 3 filter pills theo ảnh: Khoảng cách | Bán thời gian | Toàn thời gian
class SearchFilterPills extends StatelessWidget {
  const SearchFilterPills({
    super.key,
    required this.active,
    required this.onChanged,
  });

  final SearchSortFilter active;
  final ValueChanged<SearchSortFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _Pill(
            label: 'Khoảng cách',
            icon: Icons.near_me_rounded,
            isActive: active == SearchSortFilter.distance,
            onTap: () => onChanged(SearchSortFilter.distance),
          ),
          const SizedBox(width: 8),
          _Pill(
            label: 'Bán thời gian',
            isActive: active == SearchSortFilter.partTime,
            onTap: () => onChanged(SearchSortFilter.partTime),
          ),
          const SizedBox(width: 8),
          _Pill(
            label: 'Toàn thời gian',
            isActive: active == SearchSortFilter.fullTime,
            onTap: () => onChanged(SearchSortFilter.fullTime),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : const Color(0xFFD1D5DB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : const Color(0xFF374151),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
