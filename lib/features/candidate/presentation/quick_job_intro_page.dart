import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';

class QuickJobIntroPage extends ConsumerStatefulWidget {
  const QuickJobIntroPage({super.key});

  @override
  ConsumerState<QuickJobIntroPage> createState() => _QuickJobIntroPageState();
}

class _QuickJobIntroPageState extends ConsumerState<QuickJobIntroPage> {
  bool _submitting = false;

  Future<void> _handleSubmit() async {
    setState(() {
      _submitting = true;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .submitVerificationRequest();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Đã gửi yêu cầu!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Yêu cầu kích hoạt Công việc tuyển gấp đã được gửi đến admin. Bạn sẽ nhận được thông báo khi được phê duyệt (thường 1–2 ngày làm việc).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop(); // Dismiss dialog
                    Navigator.of(context).pop(); // Back to jobs screen
                  },
                  child: const Text(
                    'Về trang tuyển gấp',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gửi yêu cầu thất bại: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final user = ref.watch(authControllerProvider).asData?.value.user;
    final status = user?.verificationStatus ?? 'PENDING';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dịch vụ tuyển gấp',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Back button matching web React version
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back,
                size: 16,
                color: Color(0xFF64748B),
              ),
              label: const Text(
                'Quay lại',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
            ),
            const SizedBox(height: 20),

            // Hero Blue Gradient Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flash_on, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'TÍNH NĂNG ĐẶC BIỆT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dịch vụ tuyển gấp',
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Giải pháp tuyển dụng tức thì tối ưu. Tìm kiếm nhân sự chất lượng cao và lấp đầy ca làm trống chỉ trong vài giờ thay vì nhiều ngày.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Features Section
            Text(
              'Công việc tuyển gấp là gì?',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Các ưu điểm vượt trội của tính năng tuyển gấp',
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            _buildFeatureTile(
              icon: Icons.offline_bolt_outlined,
              iconColor: const Color(0xFFDC2626),
              iconBgColor: const Color(0xFFFEE2E2),
              title: 'Nổi bật & Đẩy tin',
              desc:
                  'Bài đăng sẽ có biểu tượng "Tuyển gấp" nổi bật và hiển thị ở vị trí ưu tiên trên trang chủ của ứng viên.',
            ),
            const SizedBox(height: 12),
            _buildFeatureTile(
              icon: Icons.groups_outlined,
              iconColor: const Color(0xFF16A34A),
              iconBgColor: const Color(0xFFDCFCE7),
              title: 'Tiếp cận Real-time',
              desc:
                  'Hệ thống tự động gửi thông báo đẩy đến điện thoại của ứng viên phù hợp trong phạm vi lân cận ngay khi tạo tin.',
            ),
            const SizedBox(height: 12),
            _buildFeatureTile(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.secondary,
              iconBgColor: AppColors.primarySoft,
              title: 'Ký quỹ an toàn',
              desc:
                  'Lương được giữ an toàn qua tài khoản ký quỹ và tự động giải ngân sau khi hoàn thành ca làm.',
            ),
            const SizedBox(height: 32),

            // Steps Section
            Text(
              'Cách thức hoạt động',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Quy trình tuyển dụng tinh gọn và nhanh chóng qua 4 bước',
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            _buildStepTile(
              stepNumber: '1',
              title: 'Gửi yêu cầu kích hoạt',
              desc:
                  'Đăng ký sử dụng tính năng và chờ hệ thống kiểm duyệt hồ sơ của bạn.',
            ),
            const SizedBox(height: 12),
            _buildStepTile(
              stepNumber: '2',
              title: 'Ký quỹ tin đăng',
              desc:
                  'Nạp tiền lương tương ứng vào ví điện tử Ốp Pờ. Hệ thống sẽ ký quỹ để đảm bảo quyền lợi ứng viên.',
            ),
            const SizedBox(height: 12),
            _buildStepTile(
              stepNumber: '3',
              title: 'Chat Real-time',
              desc:
                  'Ứng viên sẽ nhận việc tức thì. Bạn có thể chat realtime để trao đổi và hướng dẫn công việc.',
            ),
            const SizedBox(height: 12),
            _buildStepTile(
              stepNumber: '4',
              title: 'Xác nhận & Thanh toán',
              desc:
                  'Xác nhận công việc hoàn thành. Hệ thống sẽ tự động chuyển khoản từ tài khoản ký quỹ vào ví của ứng viên.',
            ),
            const SizedBox(height: 32),

            // FAQ Section
            Text(
              'Các thông tin quan trọng',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Quy định và chính sách hoạt động của công việc tuyển gấp',
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _buildFaqRow(
                    icon: Icons.error_outline,
                    q: 'Mức lương sàn tuyển gấp là bao nhiêu?',
                    a: 'Để đảm bảo thu hút ứng viên trong thời gian ngắn, lương của Công việc tuyển gấp phải cao hơn mức lương tối thiểu vùng.',
                  ),
                  const Divider(height: 1),
                  _buildFaqRow(
                    icon: Icons.trending_up,
                    q: 'Phí hoa hồng dịch vụ là bao nhiêu?',
                    a: 'Hệ thống thu phí dịch vụ 15% tính trên tổng lương ca làm việc khi bài đăng được hoàn thành thành công.',
                  ),
                  const Divider(height: 1),
                  _buildFaqRow(
                    icon: Icons.check_circle_outline,
                    q: 'Chính sách hoàn tiền ký quỹ ra sao?',
                    a: 'Nếu ca làm việc không diễn ra hoặc chưa có ứng viên phù hợp, chúng tôi sẽ giữ 15% phí sàn, 85% số tiền đã ký quỹ sẽ được hoàn trả lại ví của bạn.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // CTA Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Text(
                    'Bắt đầu sử dụng Công việc tuyển gấp',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kích hoạt tính năng ngay hôm nay để lấp đầy ca làm việc của bạn trong lịch trình bận rộn.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (status == 'APPROVED')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Color(0xFF15803D),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tài khoản đã được kích hoạt tuyển gấp!',
                            style: TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (status == 'SUBMITTED')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time_filled,
                            color: Color(0xFF92400E),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Đang chờ admin duyệt...',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _submitting ? null : _handleSubmit,
                        child: _submitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Đang gửi...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shield_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Gửi yêu cầu kích hoạt Công việc tuyển gấp',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String desc,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconColor.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile({
    required String stepNumber,
    required String title,
    required String desc,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFaqRow({
    required IconData icon,
    required String q,
    required String a,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
