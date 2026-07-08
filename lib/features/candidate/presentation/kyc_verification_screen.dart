import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/formatters/app_date_formatter.dart';
import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../data/ekyc_repository.dart';

class KycVerificationScreen extends ConsumerStatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  ConsumerState<KycVerificationScreen> createState() =>
      _KycVerificationScreenState();
}

class _KycVerificationScreenState extends ConsumerState<KycVerificationScreen> {
  final ImagePicker _picker = ImagePicker();

  int _currentStep = 0; // 0: CCCD OCR, 1: Selfie, 2: Success
  bool _loading = false;
  String _loadingMsg = '';
  String _error = '';

  // Step 0 - CCCD Images
  XFile? _frontFile;
  XFile? _backFile;
  Uint8List? _frontBytes;
  Uint8List? _backBytes;

  // Step 0 - OCR Results
  Map<String, dynamic>? _ocrResult;
  String? _frontHash;
  String? _frontToken;
  bool _ocrConfirmed = false;

  // Step 1 - Selfie Image
  XFile? _selfieFile;
  Uint8List? _selfieBytes;

  @override
  void initState() {
    super.initState();
    _checkExistingKyc();
  }

  Future<void> _checkExistingKyc() async {
    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user == null) return;

    setState(() {
      _loading = true;
      _loadingMsg = 'Đang kiểm tra trạng thái xác thực...';
    });

    try {
      final res = await ref
          .read(ekycRepositoryProvider)
          .getKycStatus(user.userId);
      if (res['success'] == true &&
          (res['kycCompleted'] == true || res['kycStatus'] == 'VERIFIED')) {
        if (mounted) {
          // If already completed, pop back to profile screen
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Error checking KYC status on load: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMsg = '';
        });
      }
    }
  }

  // ─── Image Picking Helper ──────────────────────────────────────────────────
  Future<void> _pickImage(String field, ImageSource source) async {
    setState(() {
      _error = '';
    });

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        setState(() {
          _error = 'Kích thước ảnh tối đa là 10MB';
        });
        return;
      }

      setState(() {
        if (field == 'front') {
          _frontFile = file;
          _frontBytes = bytes;
          _ocrResult = null; // Clear old OCR results if images change
          _ocrConfirmed = false;
          _frontHash = null;
          _frontToken = null;
        } else if (field == 'back') {
          _backFile = file;
          _backBytes = bytes;
          _ocrResult = null;
          _ocrConfirmed = false;
        } else if (field == 'selfie') {
          _selfieFile = file;
          _selfieBytes = bytes;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Không thể mở camera hoặc chọn ảnh: $e';
      });
    }
  }

  void _showImageSourceSelector(String field) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh mới'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(field, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh từ thư viện'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(field, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── API Flow Calls ────────────────────────────────────────────────────────
  Future<void> _submitOcr() async {
    if (_frontFile == null || _frontBytes == null) {
      setState(() => _error = 'Vui lòng tải lên ảnh mặt trước CCCD');
      return;
    }

    setState(() {
      _loading = true;
      _loadingMsg = 'Đang đọc thông tin CCCD…';
      _error = '';
    });

    try {
      final frontBase64 = base64Encode(_frontBytes!);
      final frontMime = _frontFile!.path.endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final frontDataUrl = 'data:$frontMime;base64,$frontBase64';

      String? backDataUrl;
      if (_backFile != null && _backBytes != null) {
        final backBase64 = base64Encode(_backBytes!);
        final backMime = _backFile!.path.endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        backDataUrl = 'data:$backMime;base64,$backBase64';
      }

      final res = await ref
          .read(ekycRepositoryProvider)
          .ocrCCCD(imageFront: frontDataUrl, imageBack: backDataUrl);

      if (res['success'] == true) {
        setState(() {
          _ocrResult = res['object'] as Map<String, dynamic>;
          _frontHash = res['front_hash'] as String?;
          _frontToken = res['front_token'] as String?;
        });
      } else {
        throw Exception(res['errorMsg'] ?? 'OCR thất bại');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _loading = false;
        _loadingMsg = '';
      });
    }
  }

  Future<void> _submitFaceVerify() async {
    if (_selfieFile == null || _selfieBytes == null) {
      setState(() => _error = 'Vui lòng chụp hoặc chọn ảnh khuôn mặt');
      return;
    }

    setState(() {
      _loading = true;
      _loadingMsg = 'Đang xác minh khuôn mặt…';
      _error = '';
    });

    try {
      final selfieBase64 = base64Encode(_selfieBytes!);
      final selfieMime = _selfieFile!.path.endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final selfieDataUrl = 'data:$selfieMime;base64,$selfieBase64';

      final res = await ref
          .read(ekycRepositoryProvider)
          .verifyFace(
            faceImage: selfieDataUrl,
            frontHash: _frontHash,
            frontToken: _frontToken,
          );

      if (res['kycStatus'] == 'VERIFIED') {
        // Sync name, DOB, and CCCD to database candidate profile
        final authUser = ref.read(authControllerProvider).asData?.value.user;
        if (authUser != null && _ocrResult != null) {
          try {
            final normalizedOcrDob = AppDateFormatter.normalizeDateOnly(
              _ocrResult!['dob']?.toString(),
            );
            await ref
                .read(authControllerProvider.notifier)
                .completeProfile(
                  fullName:
                      _ocrResult!['name']?.toString() ?? authUser.fullName,
                  cccd: _ocrResult!['id']?.toString() ?? authUser.cccd,
                  dateOfBirth: normalizedOcrDob ?? authUser.dateOfBirth,
                  phone: authUser.phone,
                  location: authUser.location,
                  title: authUser.title,
                  bio: authUser.bio,
                  skills: authUser.skills,
                  profileImage: authUser.profileImage,
                );
          } catch (dbErr) {
            debugPrint('DB sync warning: $dbErr');
          }
        }

        // Show verification success and transition to Step 2 (Success)
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _currentStep = 2;
            });
          }
        });
      } else {
        final double similarity =
            double.tryParse(res['object']?['similarity']?.toString() ?? '') ??
            0.0;
        setState(() {
          _error =
              'Xác minh thất bại. Độ tương đồng: ${similarity.toStringAsFixed(1)}% (yêu cầu ≥ 85%). Vui lòng chụp lại.';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _loading = false;
        _loadingMsg = '';
      });
    }
  }

  // ─── UI Rendering ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Full screen loading indicator overlay
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(height: 20),
              Text(
                _loadingMsg,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(l10n.text('kycVerification')),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () {
            if (_currentStep > 0 && _currentStep < 2) {
              setState(() {
                _currentStep--;
                _error = '';
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: _currentStep == 2
            ? _buildSuccessScreen()
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildStepper(),
                        const SizedBox(height: 32),
                        if (_error.isNotEmpty) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 20),
                        ],
                        _currentStep == 0
                            ? _buildStepCccd()
                            : _buildStepSelfie(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: AppColors.primary,
            size: 36,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Xác Minh eKYC',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Hoàn tất 2 bước để xác minh danh tính và bắt đầu ứng tuyển',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildStepper() {
    final double progress = _currentStep > 0 ? 100 : 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Connecting line
        Positioned(
          left: 60,
          right: 60,
          child: Container(height: 3, color: const Color(0xFFE2E8F0)),
        ),
        Positioned(
          left: 60,
          right: 60,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            width: double.infinity,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress / 100,
              child: Container(color: AppColors.primary),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStepCircle(
              index: 0,
              label: 'Xác minh CCCD',
              active: _currentStep == 0,
              completed: _currentStep > 0,
            ),
            _buildStepCircle(
              index: 1,
              label: 'Khuôn mặt',
              active: _currentStep == 1,
              completed: _currentStep > 1,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepCircle({
    required int index,
    required String label,
    required bool active,
    required bool completed,
  }) {
    Color bg = const Color(0xFFF1F5F9);
    Color border = const Color(0xFFCBD5E1);
    Widget child = Text(
      '${index + 1}',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF64748B),
      ),
    );

    if (completed) {
      bg = const Color(0xFF10B981);
      border = const Color(0xFF10B981);
      child = const Icon(Icons.check, color: Colors.white, size: 18);
    } else if (active) {
      bg = AppColors.primary;
      border = AppColors.primary;
      child = Text(
        '${index + 1}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(child: child),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active || completed ? FontWeight.bold : FontWeight.w500,
            color: active
                ? AppColors.primary
                : completed
                ? const Color(0xFF10B981)
                : const Color(0xFF64748B),
          ),
        ),
      ],
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
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
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

  // ─── Step 0: CCCD OCR UI ───────────────────────────────────────────────────

  Widget _buildStepCccd() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Xác Minh CCCD / CMND',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tải lên ảnh 2 mặt để hệ thống tự động đọc thông tin',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          _buildInfoBox([
            'Ảnh rõ nét, đủ sáng, không bị mờ hoặc chói sáng',
            'Định dạng JPG, PNG — tối đa 10MB mỗi ảnh',
          ]),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildUploadBox(
                  title: 'Mặt trước *',
                  bytes: _frontBytes,
                  onTap: () => _showImageSourceSelector('front'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildUploadBox(
                  title: 'Mặt sau (tuỳ chọn)',
                  bytes: _backBytes,
                  onTap: () => _showImageSourceSelector('back'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_frontFile != null && _ocrResult == null) ...[
            ElevatedButton.icon(
              onPressed: _submitOcr,
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              label: const Text(
                'Gửi Đọc Thông Tin CCCD',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_ocrResult != null) ...[
            _buildOcrResultCard(),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Hủy bỏ'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _ocrConfirmed
                      ? () {
                          setState(() {
                            _currentStep = 1;
                            _error = '';
                          });
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tiếp theo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBox({
    required String title,
    required Uint8List? bytes,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: CustomPaint(
            painter: DashedBorderPainter(
              color: bytes != null
                  ? const Color(0xFF10B981)
                  : const Color(0xFFCBD5E1),
              strokeWidth: 2,
              gap: 6,
            ),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: bytes != null
                    ? const Color(0xFF10B981).withValues(alpha: 0.02)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: Center(
                child: bytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            color: AppColors.primary,
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tải ảnh lên',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'JPG, PNG',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOcrResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Color(0xFF16A34A),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Thông tin đọc từ CCCD',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF15803D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildOcrGrid(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _ocrResult = null;
                      _frontHash = null;
                      _frontToken = null;
                      _ocrConfirmed = false;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Đọc lại'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF15803D),
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _ocrConfirmed = true;
                    });
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(_ocrConfirmed ? 'Đã xác nhận' : 'Xác nhận đúng'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOcrGrid() {
    if (_ocrResult == null) return const SizedBox();

    final id = _ocrResult!['id']?.toString() ?? '–';
    final name = _ocrResult!['name']?.toString() ?? '–';
    final rawDob = _ocrResult!['dob']?.toString();
    final dob = AppDateFormatter.formatVietnameseDateString(
      rawDob,
      fallback: rawDob ?? '–',
    );
    final sex = _ocrResult!['sex']?.toString() ?? '–';
    final address = _ocrResult!['address']?.toString() ?? '–';

    return Column(
      children: [
        _buildOcrField('Số CCCD', id),
        const Divider(height: 16),
        _buildOcrField('Họ tên', name),
        const Divider(height: 16),
        Row(
          children: [
            Expanded(child: _buildOcrField('Ngày sinh', dob)),
            const SizedBox(width: 16),
            Expanded(child: _buildOcrField('Giới tính', sex)),
          ],
        ),
        const Divider(height: 16),
        _buildOcrField('Địa chỉ thường trú', address),
      ],
    );
  }

  Widget _buildOcrField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF166534),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF14532D),
          ),
        ),
      ],
    );
  }

  // ─── Step 1: Selfie eKYC UI ────────────────────────────────────────────────

  Widget _buildStepSelfie() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Xác Minh Khuôn Mặt',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Chụp selfie để so khớp với ảnh chân dung trên CCCD',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          _buildInfoBox([
            'Nhìn thẳng vào camera, đủ sáng, không đeo kính râm hoặc khẩu trang',
            'Khuôn mặt sẽ được so khớp với ảnh CCCD (độ tương đồng ≥ 85%)',
          ]),
          const SizedBox(height: 24),
          Center(child: _buildSelfiePreview()),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                      _error = '';
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Quay lại'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selfieFile == null ? null : _submitFaceVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Hoàn Tất Xác Minh',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelfiePreview() {
    if (_selfieBytes != null) {
      return Column(
        children: [
          Container(
            height: 220,
            width: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.memory(_selfieBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _showImageSourceSelector('selfie'),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Chụp / chọn lại'),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _showImageSourceSelector('selfie'),
      child: Container(
        height: 200,
        width: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.face_outlined, color: Color(0xFF64748B), size: 48),
            SizedBox(height: 12),
            Text(
              'Chụp ảnh Selfie',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Nhấn để bắt đầu',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 2: Success Screen UI ─────────────────────────────────────────────

  Widget _buildSuccessScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 56,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '🎉 Xác Minh eKYC Hoàn Tất!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Danh tính của bạn đã được xác minh thành công qua VNPT eKYC. Tài khoản đã được cập nhật, bạn có thể bắt đầu ứng tuyển.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Về Hồ Sơ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Visual Helper Widgets ─────────────────────────────────────────────────

  Widget _buildInfoBox(List<String> bullets) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: bullets
            .map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Custom Dashed Painter ─────────────────────────────────────────────────

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );
    path.addRRect(rrect);

    final dashPath = Path();
    final double dashWidth = gap;

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final isDash = (distance ~/ dashWidth) % 2 == 0;
        if (isDash) {
          dashPath.addPath(
            metric.extractPath(distance, distance + dashWidth),
            Offset.zero,
          );
        }
        distance += dashWidth;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap;
  }
}
