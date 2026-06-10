import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/config/s3_asset_config.dart';
import '../../../../shared/presentation/widgets/network_asset_image.dart';

class HomeS3BannerCarousel extends StatefulWidget {
  const HomeS3BannerCarousel({
    super.key,
    this.autoPlayInterval = const Duration(seconds: 5),
  });

  final Duration autoPlayInterval;

  @override
  State<HomeS3BannerCarousel> createState() => _HomeS3BannerCarouselState();
}

class _HomeS3BannerCarouselState extends State<HomeS3BannerCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;

  List<String> get _banners => S3AssetConfig.candidateBanners;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final url in _banners) {
      precacheImage(
        NetworkImage(url),
        context,
        onError: (_, _) {
          // The visible image has its own placeholder. Failed preloading must
          // not surface as a page-level error when the device is offline.
        },
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!_pageController.hasClients || !mounted) return;
      final next = (_currentIndex + 1) % _banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: PageView.builder(
                controller: _pageController,
                itemCount: _banners.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  _startTimer();
                },
                itemBuilder: (_, index) => NetworkAssetImage(
                  url: _banners[index],
                  fit: BoxFit.cover,
                  semanticLabel: 'Banner quảng cáo ${index + 1}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _banners.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: index == _currentIndex ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _currentIndex
                      ? const Color(0xFF1E3A8A)
                      : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
