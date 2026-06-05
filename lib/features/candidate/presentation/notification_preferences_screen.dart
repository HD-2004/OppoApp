import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/preferences/app_preferences.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _jobRecommendations = true;
  bool _employerMessages = true;
  bool _applicationUpdates = true;
  bool _paymentUpdates = true;
  bool _systemAnnouncements = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _jobRecommendations =
          preferences.getBool(
            AppPreferenceKeys.notificationJobRecommendations,
          ) ??
          true;
      _employerMessages =
          preferences.getBool(AppPreferenceKeys.notificationEmployerMessages) ??
          true;
      _applicationUpdates =
          preferences.getBool(
            AppPreferenceKeys.notificationApplicationUpdates,
          ) ??
          true;
      _paymentUpdates =
          preferences.getBool(AppPreferenceKeys.notificationPaymentUpdates) ??
          true;
      _systemAnnouncements =
          preferences.getBool(
            AppPreferenceKeys.notificationSystemAnnouncements,
          ) ??
          false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(key, value);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).unknownError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.notificationPreferences)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              value: _jobRecommendations,
              title: Text(strings.jobRecommendations),
              onChanged: (value) {
                setState(() => _jobRecommendations = value);
                _savePreference(
                  AppPreferenceKeys.notificationJobRecommendations,
                  value,
                );
              },
            ),
            SwitchListTile(
              value: _employerMessages,
              title: Text(strings.employerMessages),
              onChanged: (value) {
                setState(() => _employerMessages = value);
                _savePreference(
                  AppPreferenceKeys.notificationEmployerMessages,
                  value,
                );
              },
            ),
            SwitchListTile(
              value: _applicationUpdates,
              title: Text(strings.applicationUpdates),
              onChanged: (value) {
                setState(() => _applicationUpdates = value);
                _savePreference(
                  AppPreferenceKeys.notificationApplicationUpdates,
                  value,
                );
              },
            ),
            SwitchListTile(
              value: _paymentUpdates,
              title: Text(strings.paymentUpdates),
              onChanged: (value) {
                setState(() => _paymentUpdates = value);
                _savePreference(
                  AppPreferenceKeys.notificationPaymentUpdates,
                  value,
                );
              },
            ),
            SwitchListTile(
              value: _systemAnnouncements,
              title: Text(strings.systemAnnouncements),
              onChanged: (value) {
                setState(() => _systemAnnouncements = value);
                _savePreference(
                  AppPreferenceKeys.notificationSystemAnnouncements,
                  value,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
