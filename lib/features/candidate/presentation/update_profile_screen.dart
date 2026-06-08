import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../auth/application/auth_controller.dart';

const _profileImageMaxDimension = 400;
const _profileImageJpegQuality = 70;

class UpdateProfileScreen extends ConsumerStatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  ConsumerState<UpdateProfileScreen> createState() =>
      _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends ConsumerState<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cccdController = TextEditingController();
  final _dobController = TextEditingController();
  final _locationController = TextEditingController();
  final _titleController = TextEditingController();
  final _bioController = TextEditingController();
  final _skillsController = TextEditingController();
  final _emailController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _zaloController = TextEditingController();
  final _websiteController = TextEditingController();

  bool _isSubmitting = false;
  String? _profileImage;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user != null) {
      _fullNameController.text = user.fullName;
      _phoneController.text = user.phone ?? '';
      _cccdController.text = user.cccd ?? '';
      _dobController.text = user.dateOfBirth ?? '';
      _locationController.text = user.location ?? '';
      _titleController.text = user.title ?? '';
      _bioController.text = user.bio ?? '';
      _skillsController.text = user.skills?.join(', ') ?? '';
      _emailController.text = user.email;
      _profileImage = user.profileImage;
      final social = user.socialLinks;
      _facebookController.text = social?['facebook'] ?? '';
      _instagramController.text = social?['instagram'] ?? '';
      _zaloController.text = social?['zalo'] ?? '';
      _websiteController.text = social?['website'] ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _cccdController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    _titleController.dispose();
    _bioController.dispose();
    _skillsController.dispose();
    _emailController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _zaloController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    final croppedBytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AvatarCropDialog(imageBytes: bytes),
    );

    if (croppedBytes == null || !mounted) return;

    setState(() {
      _profileImage = 'data:image/jpeg;base64,${base64Encode(croppedBytes)}';
    });
  }

  void _removeProfileImage() {
    setState(() {
      _profileImage = null;
    });
  }

  Future<void> _selectDate() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 18));
    if (_dobController.text.isNotEmpty) {
      try {
        initial = DateTime.parse(_dobController.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1E3A8A)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(
        () => _dobController.text = DateFormat('yyyy-MM-dd').format(picked),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final skills = _skillsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final socialLinks = <String, String>{
      if (_facebookController.text.trim().isNotEmpty)
        'facebook': _facebookController.text.trim(),
      if (_instagramController.text.trim().isNotEmpty)
        'instagram': _instagramController.text.trim(),
      if (_zaloController.text.trim().isNotEmpty)
        'zalo': _zaloController.text.trim(),
      if (_websiteController.text.trim().isNotEmpty)
        'website': _websiteController.text.trim(),
    };

    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeProfile(
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim(),
            cccd: _cccdController.text.trim(),
            dateOfBirth: _dobController.text.trim(),
            location: _locationController.text.trim(),
            title: _titleController.text.trim(),
            bio: _bioController.text.trim(),
            skills: skills,
            profileImage: _profileImage,
            socialLinks: socialLinks,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật hồ sơ thành công!'),
          backgroundColor: Color(0xFF1E3A8A),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: const BackButton(color: Color(0xFF1E293B)),
        title: const Text(
          'Cập nhật hồ sơ',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileImageSection(
                profileImage: _profileImage,
                onPickImage: _pickProfileImage,
                onRemoveImage: _removeProfileImage,
                isUploading: _isSubmitting && _profileImage != null,
              ),
              const SizedBox(height: 16),

              // ── Thông tin cá nhân ──────────────────────────────
              _SectionCard(
                title: 'Thông tin cá nhân',
                children: [
                  _Field(
                    controller: _fullNameController,
                    label: 'Họ và tên',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                  ),
                  _Field(
                    controller: _phoneController,
                    label: 'Số điện thoại',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  _Field(
                    controller: _cccdController,
                    label: 'Số CCCD',
                    icon: Icons.credit_card_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  _DateField(
                    controller: _dobController,
                    label: 'Ngày sinh',
                    onTap: _selectDate,
                  ),
                  _Field(
                    controller: _locationController,
                    label: 'Địa chỉ',
                    icon: Icons.map_outlined,
                  ),
                  _Field(
                    controller: _emailController,
                    label: 'Email (Cognito)',
                    icon: Icons.email_outlined,
                    readOnly: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Thông tin công việc & kỹ năng ──────────────────
              _SectionCard(
                title: 'Thông tin công việc & kỹ năng',
                children: [
                  _Field(
                    controller: _titleController,
                    label: 'Chức danh mong muốn',
                    icon: Icons.work_outline_rounded,
                  ),
                  _Field(
                    controller: _skillsController,
                    label: 'Kỹ năng (cách nhau bằng dấu phẩy)',
                    icon: Icons.star_outline_rounded,
                    helperText: 'Ví dụ: Pha chế, Phục vụ, Tiếng Anh',
                  ),
                  _BioField(controller: _bioController),
                ],
              ),
              const SizedBox(height: 24),

              _SectionCard(
                title: 'Liên kết mạng xã hội',
                children: [
                  _Field(
                    controller: _facebookController,
                    label: 'Facebook URL',
                    icon: Icons.facebook_rounded,
                    keyboardType: TextInputType.url,
                  ),
                  _Field(
                    controller: _instagramController,
                    label: 'Instagram URL',
                    icon: Icons.camera_alt_outlined,
                    keyboardType: TextInputType.url,
                  ),
                  _Field(
                    controller: _zaloController,
                    label: 'Zalo',
                    icon: Icons.chat_bubble_outline_rounded,
                    keyboardType: TextInputType.text,
                  ),
                  _Field(
                    controller: _websiteController,
                    label: 'Website URL',
                    icon: Icons.language_outlined,
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Submit ─────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text(
                    'Lưu Thay Đổi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D9488),
            ),
          ),
          const SizedBox(height: 16),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Text field ────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.helperText,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final String? helperText;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
        helperText: helperText,
        helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }
}

// ── Date field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({
    required this.controller,
    required this.label,
    required this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        prefixIcon: const Icon(
          Icons.calendar_today_outlined,
          size: 20,
          color: Color(0xFF9CA3AF),
        ),
        suffixIcon: const Icon(
          Icons.arrow_drop_down_rounded,
          color: Color(0xFF9CA3AF),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
        ),
      ),
    );
  }
}

// ── Bio field ─────────────────────────────────────────────────────────────────

class _BioField extends StatelessWidget {
  const _BioField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 5,
      minLines: 3,
      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
      decoration: InputDecoration(
        labelText: 'Giới thiệu bản thân',
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        alignLabelWithHint: true,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 60),
          child: Icon(
            Icons.description_outlined,
            size: 20,
            color: Color(0xFF9CA3AF),
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
        ),
      ),
    );
  }
}

class _ProfileImageSection extends StatelessWidget {
  const _ProfileImageSection({
    required this.profileImage,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.isUploading,
  });

  final String? profileImage;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ảnh đại diện',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D9488),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  _ProfileImageAvatar(profileImage: profileImage),
                  if (isUploading)
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isUploading ? null : onPickImage,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Chọn ảnh'),
                    ),
                    if (profileImage != null)
                      TextButton.icon(
                        onPressed: isUploading ? null : onRemoveImage,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFFDC2626),
                        ),
                        label: const Text(
                          'Xóa ảnh',
                          style: TextStyle(color: Color(0xFFDC2626)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileImageAvatar extends StatelessWidget {
  const _ProfileImageAvatar({required this.profileImage});

  final String? profileImage;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (profileImage != null && profileImage!.startsWith('data:image')) {
      try {
        final bytes = base64Decode(profileImage!.split(',').last);
        image = Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        image = _placeholder();
      }
    } else if (profileImage != null && profileImage!.isNotEmpty) {
      image = Image.network(
        profileImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else {
      image = _placeholder();
    }

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
      ),
      child: ClipOval(child: image),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Icon(
        Icons.person_outline_rounded,
        color: Color(0xFF9CA3AF),
        size: 34,
      ),
    );
  }
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  final GlobalKey _captureKey = GlobalKey();
  final TransformationController _controller = TransformationController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Không thể tạo ảnh crop.');
      }

      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (byteData == null) {
          throw StateError('Không thể xuất ảnh crop.');
        }

        final jpegBytes = _encodeJpegProfileImage(
          image.width,
          image.height,
          byteData.buffer,
        );

        if (!mounted) return;
        Navigator.of(context).pop(jpegBytes);
      } finally {
        image.dispose();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể chỉnh ảnh: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Uint8List _encodeJpegProfileImage(
    int width,
    int height,
    ByteBuffer rgbaBytes,
  ) {
    final source = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgbaBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final longestSide = source.width > source.height
        ? source.width
        : source.height;
    final output = longestSide > _profileImageMaxDimension
        ? img.copyResize(
            source,
            width: source.width >= source.height
                ? _profileImageMaxDimension
                : null,
            height: source.height > source.width
                ? _profileImageMaxDimension
                : null,
            interpolation: img.Interpolation.average,
          )
        : source;
    final jpegBytes = img.encodeJpg(output, quality: _profileImageJpegQuality);
    return Uint8List.fromList(jpegBytes);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = size.width < 560 ? size.width - 32 : 520.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogWidth,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Kéo để chỉnh ảnh',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kéo ảnh để đặt đúng vị trí và dùng 2 ngón/scroll để phóng to thu nhỏ.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          InteractiveViewer(
                            transformationController: _controller,
                            minScale: 1,
                            maxScale: 4,
                            panEnabled: true,
                            scaleEnabled: true,
                            boundaryMargin: const EdgeInsets.all(80),
                            child: SizedBox.expand(
                              child: Image.memory(
                                widget.imageBytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  width: 2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              margin: const EdgeInsets.all(18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Lưu ảnh'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
