import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/intro_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeFromIntroState());
  }

  Future<void> _routeFromIntroState() async {
    final introRepository = ref.read(introRepositoryProvider);
    final results = await Future.wait([
      introRepository.hasSeenIntro(),
      Future<void>.delayed(const Duration(milliseconds: 700)),
    ]);
    final hasSeenIntro = results.first as bool;
    if (!mounted) {
      return;
    }
    if (!hasSeenIntro) {
      await introRepository.markIntroAsSeen();
      if (!mounted) {
        return;
      }
    }
    context.go('/login');
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: const _SplashLogo(),
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  static const _logoAsset = 'img/oppo-logo-color.png';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logoWidth = (width * 0.38).clamp(132.0, 160.0).toDouble();

    return Image.asset(_logoAsset, width: logoWidth, fit: BoxFit.contain);
  }
}
