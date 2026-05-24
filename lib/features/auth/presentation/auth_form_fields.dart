import 'package:flutter/material.dart';

InputDecoration authInputDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: const OutlineInputBorder(),
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
