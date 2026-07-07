import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  static const _logoAsset = 'img/oppo-logo-color.png';
  static const _deepBlue = AppColors.primary;
  static const _lightBlue = AppColors.secondary;
  static const _backgroundTop = Color(0xFFF2F8FF);
  static const _backgroundBottom = Colors.white;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logoTileSize = (width * 0.46).clamp(160.0, 196.0).toDouble();
    final logoImageWidth = (logoTileSize * 0.72).clamp(0.0, 140.0).toDouble();

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_backgroundTop, _backgroundBottom],
          ),
        ),
        child: Stack(
          children: [
            const _IntroBackground(),
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LogoTile(
                              asset: _logoAsset,
                              size: logoTileSize,
                              logoWidth: logoImageWidth,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({
    required this.asset,
    required this.size,
    required this.logoWidth,
  });

  final String asset;
  final double size;
  final double logoWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [
          BoxShadow(
            color: _IntroScreenState._deepBlue.withValues(alpha: 0.14),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Center(
        child: Image.asset(asset, width: logoWidth, fit: BoxFit.contain),
      ),
    );
  }
}

class _IntroBackground extends StatelessWidget {
  const _IntroBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -64,
            left: -36,
            child: _Bubble(
              size: 190,
              color: _IntroScreenState._lightBlue.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            right: -72,
            bottom: 116,
            child: _Bubble(
              size: 220,
              color: _IntroScreenState._lightBlue.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            left: 28,
            bottom: -78,
            child: _Bubble(
              size: 180,
              color: _IntroScreenState._deepBlue.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
