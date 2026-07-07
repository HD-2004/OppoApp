import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/intro_controller.dart';

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen>
    with SingleTickerProviderStateMixin {
  static const _logoAsset = 'img/oppo-logo-color.png';
  static const _deepBlue = AppColors.primary;
  static const _lightBlue = AppColors.secondary;
  static const _backgroundTop = Color(0xFFF2F8FF);
  static const _backgroundBottom = Colors.white;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  bool _isNavigating = false;

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

  Future<void> _continueToLogin() async {
    if (_isNavigating) {
      return;
    }
    setState(() => _isNavigating = true);
    await ref.read(introControllerProvider.notifier).markIntroAsSeen();
    if (!mounted) {
      return;
    }
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final availableWidth = (width - 48).clamp(0.0, 360.0).toDouble();
    final logoTileSize = (width * 0.46).clamp(160.0, 196.0).toDouble();
    final logoImageWidth = (logoTileSize * 0.72).clamp(0.0, 140.0).toDouble();
    final buttonWidth = availableWidth.clamp(0.0, 280.0).toDouble();

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
                            const SizedBox(height: 28),
                            _ScaleTapButton(
                              width: buttonWidth,
                              isLoading: _isNavigating,
                              onPressed: _continueToLogin,
                              child: const Text('Bắt đầu ngay'),
                            ),
                            const SizedBox(height: 14),
                            _SecondaryIntroButton(
                              width: buttonWidth,
                              onPressed: _isNavigating
                                  ? null
                                  : _continueToLogin,
                              child: const Text('Đăng nhập'),
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

class _ScaleTapButton extends StatefulWidget {
  const _ScaleTapButton({
    required this.child,
    required this.onPressed,
    required this.width,
    this.isLoading = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double width;
  final bool isLoading;

  @override
  State<_ScaleTapButton> createState() => _ScaleTapButtonState();
}

class _ScaleTapButtonState extends State<_ScaleTapButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              _setPressed(false);
              widget.onPressed?.call();
            },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.width,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _IntroScreenState._deepBlue,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: _IntroScreenState._deepBlue.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : DefaultTextStyle(
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                      child: widget.child,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryIntroButton extends StatefulWidget {
  const _SecondaryIntroButton({
    required this.child,
    required this.onPressed,
    required this.width,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double width;

  @override
  State<_SecondaryIntroButton> createState() => _SecondaryIntroButtonState();
}

class _SecondaryIntroButtonState extends State<_SecondaryIntroButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _IntroScreenState._deepBlue.withValues(alpha: 0.24);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onPressed == null ? null : (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              _setPressed(false);
              widget.onPressed?.call();
            },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.width,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  color: _IntroScreenState._deepBlue,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
                child: widget.child,
              ),
            ),
          ),
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
