import 'dart:convert';

import 'package:flutter/material.dart';

class EmployerAvatar extends StatelessWidget {
  const EmployerAvatar({
    super.key,
    required this.employerName,
    this.imageUrl,
    this.size = 52,
    this.borderRadius = 12,
  });

  final String employerName;
  final String? imageUrl;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim();
    final fallback = _EmployerFallback(
      employerName: employerName,
      borderRadius: borderRadius,
    );

    Widget content = fallback;
    if (image != null && image.isNotEmpty) {
      if (image.startsWith('data:image')) {
        try {
          content = Image.memory(
            base64Decode(image.split(',').last),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback,
          );
        } catch (_) {
          content = fallback;
        }
      } else {
        content = Image.network(
          image,
          fit: BoxFit.contain,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            return wasSynchronouslyLoaded || frame != null ? child : fallback;
          },
          errorBuilder: (_, _, _) => fallback,
        );
      }
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: content,
    );
  }
}

class _EmployerFallback extends StatelessWidget {
  const _EmployerFallback({
    required this.employerName,
    required this.borderRadius,
  });

  final String employerName;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final name = employerName.trim();
    final initial = name.isEmpty ? null : name.characters.first.toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: initial == null
            ? const Icon(Icons.business_rounded, color: Color(0xFF1E40AF))
            : Text(
                initial,
                style: const TextStyle(
                  color: Color(0xFF1E40AF),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}
