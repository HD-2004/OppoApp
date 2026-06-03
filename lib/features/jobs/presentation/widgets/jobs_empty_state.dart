import 'package:flutter/material.dart';

import '../controllers/jobs_controller.dart';

class JobsEmptyState extends StatelessWidget {
  const JobsEmptyState({super.key, required this.tab});

  final JobTab tab;

  @override
  Widget build(BuildContext context) {
    final message = tab == JobTab.urgent
        ? 'Hiện chưa có việc làm gấp'
        : 'Hiện chưa có công việc phù hợp';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Icon(
            tab == JobTab.urgent
                ? Icons.bolt_outlined
                : Icons.work_off_outlined,
            size: 56,
            color: const Color(0xFFD1D5DB),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Hãy thử thay đổi bộ lọc hoặc quay lại sau.',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
