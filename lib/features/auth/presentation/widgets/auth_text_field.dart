import 'package:flutter/material.dart';

import 'auth_colors.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.readOnly = false,
    this.suffix,
    this.hintText,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool readOnly;
  final Widget? suffix;
  final String? hintText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      readOnly: readOnly,
      onChanged: onChanged,
      style: TextStyle(color: AuthColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(
          color: AuthColors.textSecondary(context),
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: TextStyle(
          color: AuthColors.primary,
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: Icon(
          icon,
          size: 22,
          color: AuthColors.textSecondary(context),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: AuthColors.fieldFill(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: AuthColors.outline(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: AuthColors.outline(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AuthColors.primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AuthColors.danger),
        ),
      ),
      validator: validator,
    );
  }
}
