import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'auth_colors.dart';

/// Decorative background với geometric shapes, blobs, dot grid.
/// Nằm sau content, không ảnh hưởng thao tác.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = AuthColors.isDark(context);
    final size = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient
        _GradientLayer(isDark: isDark),

        // Top-right circle blob
        Positioned(
          right: -size.width * 0.22,
          top: -size.height * 0.06,
          child: _CircleBlob(
            radius: size.width * 0.55,
            color: AuthColors.primary.withValues(alpha: isDark ? 0.07 : 0.09),
          ),
        ),

        // Top-left small accent circle
        Positioned(
          left: -size.width * 0.1,
          top: size.height * 0.04,
          child: _CircleBlob(
            radius: size.width * 0.28,
            color: AuthColors.secondary.withValues(alpha: isDark ? 0.05 : 0.07),
          ),
        ),

        // Bottom-left large blob
        Positioned(
          left: -size.width * 0.3,
          bottom: -size.height * 0.08,
          child: _CircleBlob(
            radius: size.width * 0.6,
            color: AuthColors.primary.withValues(alpha: isDark ? 0.05 : 0.06),
          ),
        ),

        // Dot grid — bottom right corner
        Positioned(
          right: 16,
          bottom: size.height * 0.12,
          child: _DotGrid(
            columns: 6,
            rows: 8,
            spacing: 14,
            color: AuthColors.primary.withValues(alpha: isDark ? 0.06 : 0.08),
          ),
        ),

        // Dot grid — top left corner
        Positioned(
          left: 16,
          top: size.height * 0.08,
          child: _DotGrid(
            columns: 4,
            rows: 5,
            spacing: 14,
            color: AuthColors.secondary.withValues(alpha: isDark ? 0.05 : 0.07),
          ),
        ),

        // Thin arc decoration
        Positioned(
          right: -size.width * 0.08,
          top: size.height * 0.14,
          child: _ArcDecoration(
            radius: size.width * 0.42,
            strokeWidth: 1.0,
            color: AuthColors.primary.withValues(alpha: isDark ? 0.08 : 0.10),
          ),
        ),

        // Content on top
        child,
      ],
    );
  }
}

// ── Layers ────────────────────────────────────────────────────────────────────

class _GradientLayer extends StatelessWidget {
  const _GradientLayer({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0B1120),
                  const Color(0xFF0D1728),
                  const Color(0xFF091018),
                ]
              : [
                  const Color(0xFFF0FDFA),
                  const Color(0xFFF8FAFC),
                  const Color(0xFFEFF6FF),
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

class _CircleBlob extends StatelessWidget {
  const _CircleBlob({required this.radius, required this.color});
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _DotGrid extends StatelessWidget {
  const _DotGrid({
    required this.columns,
    required this.rows,
    required this.spacing,
    required this.color,
  });

  final int columns;
  final int rows;
  final double spacing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: columns * spacing,
      height: rows * spacing,
      child: CustomPaint(
        painter: _DotGridPainter(
          columns: columns,
          rows: rows,
          spacing: spacing,
          color: color,
          dotRadius: 1.5,
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({
    required this.columns,
    required this.rows,
    required this.spacing,
    required this.color,
    required this.dotRadius,
  });

  final int columns;
  final int rows;
  final double spacing;
  final Color color;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int col = 0; col < columns; col++) {
      for (int row = 0; row < rows; row++) {
        canvas.drawCircle(
          Offset(col * spacing + dotRadius, row * spacing + dotRadius),
          dotRadius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArcDecoration extends StatelessWidget {
  const _ArcDecoration({
    required this.radius,
    required this.strokeWidth,
    required this.color,
  });

  final double radius;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius,
      height: radius,
      child: CustomPaint(
        painter: _ArcPainter(strokeWidth: strokeWidth, color: color),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.strokeWidth, required this.color});

  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      math.pi * 0.8,
      math.pi * 0.9,
      false,
      paint,
    );

    // Inner concentric arc
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.12,
        size.width * 0.76,
        size.height * 0.76,
      ),
      math.pi * 0.75,
      math.pi * 0.85,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
