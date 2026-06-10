import 'package:flutter/material.dart';

import 'auth_colors.dart';
import 'password_requirement_list.dart';

enum PasswordStrength { empty, weak, medium, strong }

PasswordStrength passwordStrength(String password) {
  if (password.isEmpty) {
    return PasswordStrength.empty;
  }
  final metCount = passwordRequirements(
    password,
  ).where((item) => item.isMet).length;
  if (metCount <= 2) {
    return PasswordStrength.weak;
  }
  if (metCount <= 4) {
    return PasswordStrength.medium;
  }
  return PasswordStrength.strong;
}

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = passwordStrength(password);
    final activeSegments = switch (strength) {
      PasswordStrength.empty => 0,
      PasswordStrength.weak => 1,
      PasswordStrength.medium => 2,
      PasswordStrength.strong => 3,
    };
    final label = switch (strength) {
      PasswordStrength.empty => 'Chưa nhập',
      PasswordStrength.weak => 'Yếu',
      PasswordStrength.medium => 'Trung bình',
      PasswordStrength.strong => 'Mạnh',
    };
    final color = switch (strength) {
      PasswordStrength.empty => AuthColors.outline(context),
      PasswordStrength.weak => AuthColors.danger,
      PasswordStrength.medium => AuthColors.warning,
      PasswordStrength.strong => AuthColors.success,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Độ mạnh mật khẩu',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AuthColors.textSecondary(context),
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < 3; index++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 6,
                  decoration: BoxDecoration(
                    color: index < activeSegments
                        ? color
                        : AuthColors.outline(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (index != 2) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}
