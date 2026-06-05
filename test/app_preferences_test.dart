import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/preferences/app_preferences.dart';

void main() {
  test('app-local preference keys are stable and unique', () {
    const keys = {
      AppPreferenceKeys.appThemeMode,
      AppPreferenceKeys.appLocale,
      AppPreferenceKeys.notificationJobRecommendations,
      AppPreferenceKeys.notificationEmployerMessages,
      AppPreferenceKeys.notificationApplicationUpdates,
      AppPreferenceKeys.notificationPaymentUpdates,
      AppPreferenceKeys.notificationSystemAnnouncements,
      AppPreferenceKeys.candidateAvailability,
      AppPreferenceKeys.deleteAccountRequestReason,
      AppPreferenceKeys.deleteAccountRequestSubmittedAt,
    };

    expect(keys.length, 10);
    expect(AppPreferenceKeys.candidateAvailability, 'candidate_availability');
    expect(
      AppPreferenceKeys.deleteAccountRequestReason,
      'delete_account_request_reason',
    );
  });
}
