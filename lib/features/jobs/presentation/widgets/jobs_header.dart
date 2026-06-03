import 'package:flutter/material.dart';

/// Top app bar cho màn hình Jobs:
/// Logo icon | "Ốp Pờ" | search icon
class JobsHeader extends StatelessWidget implements PreferredSizeWidget {
  const JobsHeader({super.key, required this.onSearchTap});

  final VoidCallback onSearchTap;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: Color(0xFF0D9488),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Ốp Pờ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D9488),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: onSearchTap,
          icon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF374151),
            size: 24,
          ),
          tooltip: 'Tìm kiếm',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
