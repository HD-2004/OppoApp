import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_colors.dart';

class OtpInputField extends StatefulWidget {
  const OtpInputField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onChanged,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onChanged;

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _syncCode() {
    final code = _controllers.map((controller) => controller.text).join();
    widget.controller.text = code;
    widget.onChanged?.call(code);
  }

  void _fillFromPaste(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 1) {
      return;
    }
    for (var index = 0; index < widget.length; index++) {
      _controllers[index].text = index < digits.length ? digits[index] : '';
    }
    _focusNodes[digits.length.clamp(1, widget.length) - 1].requestFocus();
    _syncCode();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < widget.length; index++) ...[
          Expanded(
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AuthColors.textPrimary(context),
                fontWeight: FontWeight.w900,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AuthColors.fieldFill(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AuthColors.outline(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AuthColors.outline(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AuthColors.primary,
                    width: 1.8,
                  ),
                ),
              ),
              onChanged: (value) {
                _fillFromPaste(value);
                if (value.length > 1) {
                  return;
                }
                if (value.isNotEmpty && index < widget.length - 1) {
                  _focusNodes[index + 1].requestFocus();
                }
                if (value.isEmpty && index > 0) {
                  _focusNodes[index - 1].requestFocus();
                }
                _syncCode();
              },
            ),
          ),
          if (index != widget.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
