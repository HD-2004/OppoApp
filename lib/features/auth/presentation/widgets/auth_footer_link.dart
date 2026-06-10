import 'package:flutter/material.dart';

import 'auth_colors.dart';

class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.text,
    required this.actionText,
    required this.onPressed,
  });

  final String text;
  final String actionText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text.rich(
        TextSpan(
          text: '$text ',
          style: TextStyle(color: AuthColors.textSecondary(context)),
          children: [
            TextSpan(
              text: actionText,
              style: const TextStyle(
                color: AuthColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
