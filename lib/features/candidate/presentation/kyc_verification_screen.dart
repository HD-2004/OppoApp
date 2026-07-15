import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../data/ekyc_repository.dart';

enum _KycPhase { idle, redirectReady, polling, done, failed }

class KycVerificationScreen extends ConsumerStatefulWidget {
  const KycVerificationScreen({super.key, this.callbackStatus});

  final String? callbackStatus;

  @override
  ConsumerState<KycVerificationScreen> createState() =>
      _KycVerificationScreenState();
}

class _KycVerificationScreenState extends ConsumerState<KycVerificationScreen> {
  static const _pollInterval = Duration(seconds: 5);
  static const _pollMaxAttempts = 60;

  Timer? _pollTimer;
  var _phase = _KycPhase.idle;
  var _loading = true;
  var _loadingMessage = '';
  var _error = '';
  var _redirectUrl = '';
  var _pollCount = 0;
  var _statusChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkInitialStatus());
    });
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  Future<void> _checkInitialStatus() async {
    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user == null) {
      setState(() {
        _loading = false;
        _loadingMessage = '';
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadingMessage = 'Đang kiểm tra trạng thái xác thực...';
      _error = '';
    });

    try {
      final status = await ref
          .read(ekycRepositoryProvider)
          .getKycStatus(user.userId);
      if (_isVerified(status)) {
        await _markLocalKycCompletedIfNeeded();
        if (!mounted) return;
        setState(() => _phase = _KycPhase.done);
      } else if (_isFailed(status)) {
        setState(() {
          _phase = _KycPhase.failed;
          _error = 'Xác minh không thành công. Vui lòng thử lại.';
        });
      } else if (_hasCompletionCallback) {
        setState(() => _phase = _KycPhase.polling);
        _startPolling();
      }
    } catch (e) {
      debugPrint('[KYC] Initial status check failed: $e');
      if (_hasCompletionCallback) {
        setState(() {
          _phase = _KycPhase.polling;
          _error = '';
        });
        _startPolling();
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMessage = '';
          _statusChecked = true;
        });
      }
    }
  }

  Future<void> _startVerification() async {
    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user == null) {
      setState(() {
        _error = 'Cần đăng nhập để xác minh danh tính.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadingMessage = 'Đang tạo phiên xác minh...';
      _error = '';
    });

    try {
      final result = await ref
          .read(ekycRepositoryProvider)
          .createVerificationSession(callbackUrl: _buildCallbackUrl());
      final redirectUrl =
          result['redirect_url']?.toString() ??
          result['redirectUrl']?.toString() ??
          '';
      if (result['success'] == false || redirectUrl.trim().isEmpty) {
        throw Exception(
          result['errorMsg'] ??
              result['message'] ??
              'Không lấy được link xác minh.',
        );
      }

      setState(() {
        _redirectUrl = redirectUrl.trim();
        _phase = _KycPhase.redirectReady;
      });
    } catch (e) {
      setState(() {
        _phase = _KycPhase.idle;
        _error = _cleanError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMessage = '';
        });
      }
    }
  }

  Future<void> _openDidit() async {
    if (_redirectUrl.trim().isEmpty) return;

    final uri = Uri.tryParse(_redirectUrl);
    if (uri == null) {
      setState(() => _error = 'Link xác minh không hợp lệ.');
      return;
    }

    setState(() {
      _phase = _KycPhase.polling;
      _error = '';
    });
    _startPolling();

    final launched = await launchUrl(
      uri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!launched && mounted) {
      setState(() {
        _error =
            'Không mở được trang Didit. Vui lòng kiểm tra trình duyệt và thử lại.';
      });
    }
  }

  Future<void> _manualCheck() async {
    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user == null) return;

    setState(() {
      _loading = true;
      _loadingMessage = 'Đang kiểm tra kết quả...';
      _error = '';
    });

    try {
      final status = await ref
          .read(ekycRepositoryProvider)
          .getKycStatus(user.userId);
      await _handleStatusResult(status, showNoResultMessage: true);
    } catch (e) {
      setState(() {
        _error = _cleanError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMessage = '';
        });
      }
    }
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    _pollCount = 0;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollStatus());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollStatus() async {
    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user == null || !mounted) return;

    setState(() => _pollCount++);

    if (_pollCount > _pollMaxAttempts) {
      _stopPolling();
      setState(() {
        _phase = _KycPhase.idle;
        _error =
            'Chưa nhận được kết quả xác minh. Vui lòng kiểm tra lại sau vài phút.';
      });
      return;
    }

    try {
      final status = await ref
          .read(ekycRepositoryProvider)
          .getKycStatus(user.userId);
      await _handleStatusResult(status);
    } catch (e) {
      debugPrint('[KYC] Poll failed: $e');
    }
  }

  Future<void> _handleStatusResult(
    Map<String, dynamic> status, {
    bool showNoResultMessage = false,
  }) async {
    if (_isVerified(status)) {
      _stopPolling();
      await _markLocalKycCompletedIfNeeded();
      if (!mounted) return;
      setState(() {
        _phase = _KycPhase.done;
        _error = '';
      });
      return;
    }

    if (_isFailed(status)) {
      _stopPolling();
      setState(() {
        _phase = _KycPhase.failed;
        _error = 'Xác minh không thành công. Vui lòng thử lại.';
      });
      return;
    }

    if (showNoResultMessage) {
      setState(() {
        _error =
            'Chưa có kết quả. Didit cần vài phút để xử lý. Vui lòng thử lại sau.';
      });
    }
  }

  Future<void> _markLocalKycCompletedIfNeeded() async {
    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user == null || user.kycCompleted) return;

    try {
      await ref.read(authControllerProvider.notifier).completeKyc();
    } catch (e) {
      debugPrint('[KYC] Local profile sync warning: $e');
    }
  }

  bool _isVerified(Map<String, dynamic> status) {
    final normalizedStatus = status['kycStatus']?.toString().toUpperCase();
    final normalizedEkyc = status['ekycStatus']?.toString().toUpperCase();
    return status['kycCompleted'] == true ||
        normalizedStatus == 'VERIFIED' ||
        normalizedEkyc == 'VERIFIED' ||
        normalizedEkyc == 'APPROVED';
  }

  bool _isFailed(Map<String, dynamic> status) {
    final normalizedStatus = status['kycStatus']?.toString().toUpperCase();
    final normalizedEkyc = status['ekycStatus']?.toString().toUpperCase();
    return normalizedStatus == 'FAILED' ||
        normalizedStatus == 'REJECTED' ||
        normalizedEkyc == 'FAILED' ||
        normalizedEkyc == 'REJECTED';
  }

  bool get _hasCompletionCallback {
    final status =
        widget.callbackStatus ??
        Uri.base.queryParameters['status'] ??
        _fragmentQueryParameters['status'];
    final normalized = status?.toLowerCase();
    return normalized == 'completed' ||
        normalized == 'approved' ||
        normalized == 'success';
  }

  Map<String, String> get _fragmentQueryParameters {
    final fragment = Uri.base.fragment;
    final queryIndex = fragment.indexOf('?');
    if (queryIndex < 0 || queryIndex == fragment.length - 1) {
      return const <String, String>{};
    }
    return Uri.splitQueryString(fragment.substring(queryIndex + 1));
  }

  String _buildCallbackUrl() {
    final base = Uri.base;
    final normalizedPath = base.path.isEmpty
        ? '/'
        : base.path.endsWith('/')
        ? base.path
        : '${base.path}/';
    return base
        .replace(
          path: normalizedPath,
          query: '',
          fragment: '/candidate/kyc?status=completed',
        )
        .toString();
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(l10n.text('kycVerification')),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      if (_error.isNotEmpty) ...[
                        _buildErrorBanner(),
                        const SizedBox(height: 18),
                      ],
                      _buildPhaseCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_loading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Xác Minh Danh Tính',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Xác minh CCCD để bắt đầu ứng tuyển việc làm trên OpPo',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
        ),
      ],
    );
  }

  Widget _buildPhaseCard() {
    return switch (_phase) {
      _KycPhase.done => _buildDoneCard(),
      _KycPhase.redirectReady => _buildRedirectCard(),
      _KycPhase.polling => _buildPollingCard(),
      _KycPhase.failed || _KycPhase.idle => _buildIntroCard(),
    };
  }

  Widget _buildIntroCard() {
    return _KycCard(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBox(
            'Quy trình xác minh được thực hiện qua nền tảng Didit, đảm bảo an toàn và bảo mật. Bạn sẽ được chuyển đến trang Didit để hoàn tất xác minh CCCD và nhận diện khuôn mặt.',
          ),
          const SizedBox(height: 22),
          const _KycStepItem(
            number: '1',
            text:
                'Nhấn "Bắt đầu xác minh" để hệ thống tạo phiên xác minh bảo mật.',
          ),
          const _KycStepItem(
            number: '2',
            text: 'Bạn sẽ được chuyển đến Didit để chụp CCCD và selfie.',
          ),
          const _KycStepItem(
            number: '3',
            text: 'Quay lại Ốp Pờ, kết quả xác minh sẽ được cập nhật tự động.',
            isLast: true,
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: _loading ? null : _startVerification,
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: const Text('Bắt Đầu Xác Minh Danh Tính'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_statusChecked) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loading ? null : _manualCheck,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Kiểm tra trạng thái hiện tại'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRedirectCard() {
    return _KycCard(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CenteredStatusHeader(
            icon: Icons.open_in_new_rounded,
            color: AppColors.primary,
            background: Color(0xFFEFF6FF),
            title: 'Phiên xác minh đã sẵn sàng',
            body:
                'Nhấn nút bên dưới để mở trang xác minh Didit trong tab mới. Sau khi hoàn tất, quay lại trang này.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openDidit,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Mở Trang Xác Minh Didit'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              _stopPolling();
              setState(() {
                _phase = _KycPhase.idle;
                _redirectUrl = '';
                _error = '';
              });
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  Widget _buildPollingCard() {
    return _KycCard(
      accentColor: const Color(0xFFF59E0B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CenteredStatusHeader(
            icon: Icons.schedule_rounded,
            color: Color(0xFFD97706),
            background: Color(0xFFFEF3C7),
            title: 'Đang chờ kết quả xác minh',
            body:
                'Nếu bạn đã hoàn tất xác minh trên Didit, hệ thống sẽ tự động cập nhật trong vài phút.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Đang kiểm tra kết quả... ($_pollCount/$_pollMaxAttempts)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _loading ? null : _manualCheck,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Kiểm tra ngay'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_redirectUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _openDidit,
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text('Mở lại trang Didit'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDoneCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.25),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Xác Minh Danh Tính Hoàn Tất!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Danh tính của bạn đã được xác minh thành công qua Didit. Tài khoản đã được cập nhật, bạn có thể bắt đầu ứng tuyển.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, height: 1.6, fontSize: 14),
          ),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF059669),
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Về Hồ Sơ'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(height: 16),
              Text(
                _loadingMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycCard extends StatelessWidget {
  const _KycCard({required this.child, required this.accentColor});

  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: accentColor),
          Padding(padding: const EdgeInsets.all(24), child: child),
        ],
      ),
    );
  }
}

class _KycStepItem extends StatelessWidget {
  const _KycStepItem({
    required this.number,
    required this.text,
    this.isLast = false,
  });

  final String number;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredStatusHeader extends StatelessWidget {
  const _CenteredStatusHeader({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}
