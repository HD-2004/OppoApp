import 'package:flutter/material.dart';

/// Skeleton loading — hiển thị khi đang tải job từ backend
class JobsLoadingSkeleton extends StatefulWidget {
  const JobsLoadingSkeleton({super.key});

  @override
  State<JobsLoadingSkeleton> createState() => _JobsLoadingSkeletonState();
}

class _JobsLoadingSkeletonState extends State<JobsLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final shimmerColor = Color.lerp(
          const Color(0xFFE5E7EB),
          const Color(0xFFF3F4F6),
          _animation.value,
        )!;

        return Column(
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge + salary row
                    Row(
                      children: [
                        _Box(w: 64, h: 22, color: shimmerColor, radius: 6),
                        const Spacer(),
                        _Box(w: 72, h: 18, color: shimmerColor, radius: 4),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Title
                    _Box(
                      w: double.infinity,
                      h: 18,
                      color: shimmerColor,
                      radius: 4,
                    ),
                    const SizedBox(height: 6),
                    _Box(w: 160, h: 14, color: shimmerColor, radius: 4),
                    const SizedBox(height: 12),
                    // Company row
                    Row(
                      children: [
                        _Box(w: 28, h: 28, color: shimmerColor, radius: 6),
                        const SizedBox(width: 8),
                        _Box(w: 120, h: 14, color: shimmerColor, radius: 4),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Location
                    _Box(w: 140, h: 12, color: shimmerColor, radius: 4),
                    const SizedBox(height: 6),
                    // Time
                    _Box(w: 100, h: 12, color: shimmerColor, radius: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.w,
    required this.h,
    required this.color,
    this.radius = 4,
  });

  final double w;
  final double h;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
