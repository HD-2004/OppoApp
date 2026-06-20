import 'package:flutter/material.dart';

import '../../../../core/config/s3_asset_config.dart';
import '../../../../shared/presentation/widgets/network_asset_image.dart';
import 'auth_colors.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    this.title,
    this.subtitle,
    this.compact = false,
    this.icon,
  });

  final String? title;
  final String? subtitle;
  final bool compact;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = AuthColors.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: compact ? 78 : 92,
          height: compact ? 78 : 92,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16243A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: icon == null
              ? _OppoLogo(size: compact ? 78 : 92)
              : Icon(
                  icon,
                  color: isDark ? AuthColors.accent : AuthColors.primary,
                  size: compact ? 32 : 38,
                ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ốp Pờ',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            color: isDark ? AuthColors.darkTextPrimary : AuthColors.primary,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        if (title != null) ...[
          SizedBox(height: compact ? 18 : 26),
          Text(
            title!,
            textAlign: TextAlign.center,
            style:
                (compact ? textTheme.headlineSmall : textTheme.headlineMedium)
                    ?.copyWith(
                      color: AuthColors.textPrimary(context),
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AuthColors.textSecondary(context),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OppoLogo extends StatelessWidget {
  const _OppoLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    // Real brand logo stored on S3. Falls back to the drawn mark if the
    // image fails to load or is still loading.
    return NetworkAssetImage(
      url: S3AssetConfig.logo,
      fit: BoxFit.contain,
      semanticLabel: 'Logo Ốp Pờ',
      placeholder: _OppoLogoMark(size: size),
    );
  }
}

class _OppoLogoMark extends StatelessWidget {
  const _OppoLogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final markSize = size * 0.72;

    return Center(
      child: SizedBox(
        width: markSize,
        height: markSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: markSize * 0.05,
              top: markSize * 0.12,
              child: Container(
                width: markSize * 0.64,
                height: markSize * 0.64,
                decoration: const BoxDecoration(
                  color: AuthColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: markSize * 0.05,
              bottom: markSize * 0.1,
              child: Container(
                width: markSize * 0.62,
                height: markSize * 0.62,
                decoration: const BoxDecoration(
                  color: AuthColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Transform.rotate(
              angle: -0.76,
              child: Container(
                width: markSize * 0.48,
                height: markSize * 0.48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(markSize * 0.12),
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: AuthColors.primary,
                  size: markSize * 0.28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
