import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';

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
  
  bool _isSubmitting = false;

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
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime initialDate = DateTime.now().subtract(const Duration(days: 365 * 18));
    if (_dobController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_dobController.text);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    
    // Parse skills list
    final List<String> skillsList = _skillsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeProfile(
            fullName: _fullNameController.text,
            phone: _phoneController.text,
            cccd: _cccdController.text,
            dateOfBirth: _dobController.text,
            location: _locationController.text,
            title: _titleController.text,
            bio: _bioController.text,
            skills: skillsList,
          );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).isVietnamese
                  ? 'Cập nhật hồ sơ thành công!'
                  : 'Profile updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).isVietnamese
                  ? 'Lỗi cập nhật hồ sơ: $e'
                  : 'Error updating profile: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isVi = l10n.isVietnamese;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.text('updateProfile')),
        elevation: 0,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isVi ? 'Thông tin cá nhân' : 'Personal Details',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Full Name
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: l10n.fullName,
                            prefixIcon: const Icon(Icons.person_outline),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.text('requiredField');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Phone Number
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: isVi ? 'Số điện thoại' : 'Phone number',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Citizen ID (CCCD)
                        TextFormField(
                          controller: _cccdController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isVi ? 'Số CCCD' : 'Citizen ID',
                            prefixIcon: const Icon(Icons.credit_card_outlined),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Date of Birth
                        TextFormField(
                          controller: _dobController,
                          readOnly: true,
                          onTap: _selectDate,
                          decoration: InputDecoration(
                            labelText: isVi ? 'Ngày sinh' : 'Date of birth',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Location
                        TextFormField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: isVi ? 'Địa chỉ' : 'Location',
                            prefixIcon: const Icon(Icons.map_outlined),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        Text(
                          isVi ? 'Thông tin công việc & kỹ năng' : 'Job & Skills Info',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Job Title
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: isVi ? 'Chức danh mong muốn' : 'Desired Position',
                            prefixIcon: const Icon(Icons.work_outline),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Skills
                        TextFormField(
                          controller: _skillsController,
                          decoration: InputDecoration(
                            labelText: isVi ? 'Kỹ năng (cách nhau bằng dấu phẩy)' : 'Skills (separated by commas)',
                            helperText: isVi ? 'Ví dụ: Pha chế, Phục vụ, Tiếng Anh' : 'Example: Mixology, Waiting, English',
                            prefixIcon: const Icon(Icons.star_outline),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Bio
                        TextFormField(
                          controller: _bioController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: isVi ? 'Giới thiệu bản thân' : 'About yourself',
                            prefixIcon: const Icon(Icons.description_outlined),
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        
                        FilledButton.icon(
                          onPressed: _isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            isVi ? 'Lưu Thay Đổi' : 'Save Changes',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
