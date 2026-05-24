import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import 'user_home_feed_screen.dart';
import 'user_jobs_screen.dart';
import 'user_notifications_screen.dart';
import 'user_profile_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    const tabs = [
      UserHomeFeedScreen(),
      UserJobsScreen(),
      UserNotificationsScreen(),
      UserProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: strings.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.work_outline),
            selectedIcon: const Icon(Icons.work),
            label: strings.jobs,
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_none),
            selectedIcon: const Icon(Icons.notifications),
            label: strings.notifications,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: strings.profile,
          ),
        ],
      ),
    );
  }
}
