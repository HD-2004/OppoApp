import 'package:flutter/material.dart';

const authInputTextStyle = TextStyle(color: Colors.black);

InputDecoration authInputDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 24),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD8E5E6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD8E5E6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF08798A), width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFB3261E)),
    ),
  );
}

String? requiredTextValidator(String? value, {String? message}) {
  if (value == null || value.trim().isEmpty) {
    return message ?? 'Không được để trống';
  }
  return null;
}

String? cognitoPasswordValidator(
  String? value, {
  String? requiredMessage,
  String? weakPasswordMessage,
}) {
  final requiredError = requiredTextValidator(value, message: requiredMessage);
  if (requiredError != null) {
    return requiredError;
  }

  final password = value!;
  if (password.length < 8) {
    return weakPasswordMessage ?? 'Mật khẩu cần ít nhất 8 ký tự';
  }
  if (!RegExp('[a-z]').hasMatch(password)) {
    return weakPasswordMessage ?? 'Mật khẩu cần có chữ thường';
  }
  if (!RegExp('[A-Z]').hasMatch(password)) {
    return weakPasswordMessage ?? 'Mật khẩu cần có chữ hoa';
  }
  if (!RegExp('[0-9]').hasMatch(password)) {
    return weakPasswordMessage ?? 'Mật khẩu cần có số';
  }
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]').hasMatch(password)) {
    return weakPasswordMessage ?? 'Mật khẩu cần có ký tự đặc biệt';
  }

  return null;
}
