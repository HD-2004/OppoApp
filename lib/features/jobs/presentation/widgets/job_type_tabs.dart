import 'package:flutter/material.dart';

import '../controllers/jobs_controller.dart';

/// 2 tabs: "Việc làm thường" | "Việc làm gấp"
/// Tab được chọn: nền trắng + border, shadow nhẹ.
/// Tab chưa chọn: nền xanh teal nhạt.
class JobTypeTabs extends StatelessWidget {
  const JobTypeTabs({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final JobTab selectedTab;
  final ValueChanged<JobTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1), // teal-50
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Việc làm thường',
            isSelected: selectedTab == JobTab.normal,
            onTap: () => onTabChanged(JobTab.normal),
          ),
          _TabButton(
            label: 'Việc làm gấp',
            isSelected: selectedTab == JobTab.urgent,
            onTap: () => onTabChanged(JobTab.urgent),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? const Color(0xFF0D9488)
                  : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}
