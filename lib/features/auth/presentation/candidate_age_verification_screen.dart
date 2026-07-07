import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';
import '../domain/candidate_age_policy.dart';

class CandidateAgeVerificationScreen extends ConsumerStatefulWidget {
  const CandidateAgeVerificationScreen({super.key});

  @override
  ConsumerState<CandidateAgeVerificationScreen> createState() =>
      _CandidateAgeVerificationScreenState();
}

class _CandidateAgeVerificationScreenState
    extends ConsumerState<CandidateAgeVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateOfBirthController = TextEditingController();
  bool _isSubmitting = false;
  String? _blockingMessage;

  @override
  void dispose() {
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    var initialDate = DateTime.now().subtract(
      const Duration(days: 365 * CandidateAgePolicy.minimumAge),
    );
    final existing = CandidateAgePolicy.parseDate(_dateOfBirthController.text);
    if (existing != null) {
      initialDate = existing;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _dateOfBirthController.text = CandidateAgePolicy.formatDate(picked);
      _blockingMessage = null;
    });
  }

  Future<void> _submit() async {
    final validation = CandidateAgePolicy.validateDateOfBirth(
      _dateOfBirthController.text,
    );
    if (validation == CandidateAgePolicy.underageMessage) {
      setState(() => _blockingMessage = validation);
      await ref.read(authControllerProvider.notifier).signOut();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _blockingMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .saveDateOfBirth(_dateOfBirthController.text.trim());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 46,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Xác minh độ tuổi',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vui lòng nhập ngày sinh để tiếp tục sử dụng Ốp Pờ.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _dateOfBirthController,
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.done,
                      validator: CandidateAgePolicy.validateDateOfBirth,
                      decoration: InputDecoration(
                        labelText: 'Ngày sinh',
                        hintText: 'yyyy-MM-dd',
                        prefixIcon: const Icon(Icons.calendar_month_outlined),
                        suffixIcon: IconButton(
                          tooltip: 'Chọn ngày sinh',
                          icon: const Icon(Icons.event_outlined),
                          onPressed: _isSubmitting ? null : _selectDateOfBirth,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    if (_blockingMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _blockingMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Tiếp tục'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
