import 'package:flutter/material.dart';

import 'auth_colors.dart';

class PasswordRequirement {
  const PasswordRequirement({required this.label, required this.isMet});

  final String label;
  final bool isMet;
}

List<PasswordRequirement> passwordRequirements(String password) {
  return [
    PasswordRequirement(
      label: 'Tối thiểu 8 ký tự',
      isMet: password.length >= 8,
    ),
    PasswordRequirement(
      label: 'Có chữ hoa',
      isMet: RegExp('[A-Z]').hasMatch(password),
    ),
    PasswordRequirement(
      label: 'Có chữ thường',
      isMet: RegExp('[a-z]').hasMatch(password),
    ),
    PasswordRequirement(
      label: 'Có số',
      isMet: RegExp('[0-9]').hasMatch(password),
    ),
    PasswordRequirement(
      label: 'Có ký tự đặc biệt',
      isMet: RegExp(
        r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]',
      ).hasMatch(password),
    ),
  ];
}

class PasswordRequirementList extends StatelessWidget {
  const PasswordRequirementList({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final items = passwordRequirements(password);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          _RequirementChip(label: item.label, isMet: item.isMet),
      ],
    );
  }
}

class _RequirementChip extends StatelessWidget {
  const _RequirementChip({required this.label, required this.isMet});

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isMet
            ? AuthColors.success.withValues(alpha: 0.12)
            : AuthColors.fieldFill(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isMet
              ? AuthColors.success.withValues(alpha: 0.35)
              : AuthColors.outline(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_rounded : Icons.circle_outlined,
            size: 14,
            color: isMet
                ? AuthColors.success
                : AuthColors.textSecondary(context),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isMet
                  ? AuthColors.success
                  : AuthColors.textSecondary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
