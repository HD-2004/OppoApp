import 'package:flutter/material.dart';

class NetworkAssetImage extends StatelessWidget {
  const NetworkAssetImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticLabel,
    this.placeholder,
  });

  final String url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final fallback =
        placeholder ??
        const ColoredBox(
          color: Color(0xFFF3F4F6),
          child: Center(
            child: Icon(Icons.image_outlined, color: Color(0xFF9CA3AF)),
          ),
        );

    Widget image = Image.network(
      url,
      fit: fit,
      semanticLabel: semanticLabel,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return fallback;
      },
      errorBuilder: (_, _, _) => fallback,
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}
