import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class OppoHomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const OppoHomeHeader({
    super.key,
    this.searchController,
    this.onSearchChanged,
    this.onChatPressed,
  });

  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onChatPressed;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerColor =
        theme.appBarTheme.backgroundColor ??
        (isDark ? const Color(0xFF0F172A) : Colors.white);
    final controlColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF1F5F9);
    final textColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    const placeholderColor = Color(0xFF64748B);

    return Material(
      color: headerColor,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 72),
                  child: Text(
                    'Ốp Pờ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ) ??
                        const TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeaderSearchField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    backgroundColor: controlColor,
                    textColor: textColor,
                    placeholderColor: placeholderColor,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Tin nhắn',
                  onPressed: onChatPressed,
                  style: IconButton.styleFrom(
                    backgroundColor: controlColor,
                    fixedSize: const Size(46, 46),
                    minimumSize: const Size(44, 44),
                    shape: const CircleBorder(),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: textColor,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSearchField extends StatelessWidget {
  const _HeaderSearchField({
    required this.backgroundColor,
    required this.textColor,
    required this.placeholderColor,
    this.controller,
    this.onChanged,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Color backgroundColor;
  final Color textColor;
  final Color placeholderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        maxLines: 1,
        style: TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Tìm việc, quán cà phê, nhà hàng...',
          hintStyle: TextStyle(color: placeholderColor, fontSize: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: placeholderColor,
            size: 20,
          ),
          filled: true,
          fillColor: backgroundColor,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
