import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class IntroductionScreen extends StatelessWidget {
  const IntroductionScreen({super.key});

  static const _brandTeal = Color(0xFF08798A);
  static const _deepText = Color(0xFF061B2B);
  static const _mutedText = Color(0xFF2E3F48);
  static const _warmBackground = Color(0xFFF8FAFF);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _warmBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                children: [
                  Text(
                    'Ốp Pờ',
                    textAlign: TextAlign.center,
                    style: textTheme.displaySmall?.copyWith(
                      color: _brandTeal,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bắt đầu hành trình sự nghiệp F&B của bạn',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: _mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _FnbHeroIllustration(),
                  const SizedBox(height: 34),
                  Text(
                    'Tìm việc linh hoạt, thu nhập tức thì',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: _deepText,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Hàng ngàn cơ hội làm việc tại các nhà hàng, quán cà phê đang chờ đón bạn. Nhận lương ngay sau ca làm, chủ động thời gian của chính mình.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: _mutedText,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 34),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BenefitItem(
                        icon: Icons.schedule_rounded,
                        label: 'Linh hoạt',
                      ),
                      _BenefitItem(
                        icon: Icons.payments_outlined,
                        label: 'Lương liền',
                      ),
                      _BenefitItem(
                        icon: Icons.verified_outlined,
                        label: 'Uy tín',
                      ),
                    ],
                  ),
                  const SizedBox(height: 44),
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandTeal,
                        foregroundColor: Colors.white,
                        textStyle: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => context.go('/login'),
                      child: const Text('Bắt đầu ngay'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text.rich(
                      TextSpan(
                        text: 'Bạn đã có tài khoản? ',
                        children: [
                          TextSpan(
                            text: 'Đăng nhập',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            color: Color(0xFF08798A),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 25),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF1E3038),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FnbHeroIllustration extends StatelessWidget {
  const _FnbHeroIllustration();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF08798A).withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset('img/intro.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}
