import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';

import '../controllers/jobs_controller.dart';

/// 3 pill filter buttons: Khu vực | Mức lương | Ngành nghề
/// Options được derive từ dữ liệu job thật (không hardcode).
class JobFilterBar extends StatelessWidget {
  const JobFilterBar({
    super.key,
    required this.filter,
    required this.availableLocations,
    required this.availableIndustries,
    required this.onFilterChanged,
  });

  final JobsFilter filter;
  final List<String> availableLocations;
  final List<String> availableIndustries;
  final ValueChanged<JobsFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Khu vực
          _FilterPill(
            label: filter.location.isEmpty ? 'Khu vực' : filter.location,
            isActive: filter.location.isNotEmpty,
            onTap: () => _showLocationSheet(context),
          ),
          const SizedBox(width: 8),
          // Mức lương
          _FilterPill(
            label: filter.salaryRange.isEmpty
                ? 'Mức lương'
                : filter.salaryRange,
            isActive: filter.salaryRange.isNotEmpty,
            onTap: () => _showSalarySheet(context),
          ),
          const SizedBox(width: 8),
          // Ngành nghề
          _FilterPill(
            label: filter.industry.isEmpty ? 'Ngành nghề' : filter.industry,
            isActive: filter.industry.isNotEmpty,
            onTap: () => _showIndustrySheet(context),
          ),
          // Clear all — chỉ hiện khi có filter
          if (filter.hasActiveFilter) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onFilterChanged(const JobsFilter()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Color(0xFFEF4444),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Xóa',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showLocationSheet(BuildContext context) {
    if (availableLocations.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có dữ liệu khu vực')));
      return;
    }
    _showOptionsSheet(
      context: context,
      title: 'Chọn khu vực',
      options: availableLocations,
      selected: filter.location,
      onSelected: (val) => onFilterChanged(filter.copyWith(location: val)),
    );
  }

  void _showSalarySheet(BuildContext context) {
    _showOptionsSheet(
      context: context,
      title: 'Chọn mức lương',
      options: JobsState.salaryRanges,
      selected: filter.salaryRange,
      onSelected: (val) => onFilterChanged(filter.copyWith(salaryRange: val)),
    );
  }

  void _showIndustrySheet(BuildContext context) {
    if (availableIndustries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có dữ liệu ngành nghề')),
      );
      return;
    }
    _showOptionsSheet(
      context: context,
      title: 'Chọn ngành nghề',
      options: availableIndustries,
      selected: filter.industry,
      onSelected: (val) => onFilterChanged(filter.copyWith(industry: val)),
    );
  }

  void _showOptionsSheet({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    if (selected.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onSelected('');
                        },
                        child: const Text(
                          'Xóa',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final opt = options[i];
                    final isSelected = opt == selected;
                    return ListTile(
                      title: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.secondary
                              : const Color(0xFF374151),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.secondary,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelected(opt);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.secondary : const Color(0xFFD1D5DB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF374151),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }
}
