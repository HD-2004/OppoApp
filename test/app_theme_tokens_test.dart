import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:oppo_temp_jobs/core/theme/app_theme.dart';

void main() {
  test('light and dark themes keep the Oppo brand primary color', () {
    expect(AppTheme.lightTheme.colorScheme.primary, AppColors.primary);
    expect(AppTheme.darkTheme.colorScheme.primary, AppColors.primary);
  });

  test('dark theme exposes readable surface and text tokens', () {
    final scheme = AppTheme.darkTheme.colorScheme;

    expect(scheme.surface, AppColors.darkBackground);
    expect(scheme.onSurface, AppColors.darkTextPrimary);
    expect(scheme.outline, AppColors.darkOutline);
  });
}
