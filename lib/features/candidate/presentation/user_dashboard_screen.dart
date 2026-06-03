import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import 'digital_wallet_screen.dart';
import 'user_jobs_screen.dart';
import '../notifications/application/notification_controller.dart';
import '../notifications/presentation/candidate_notifications_screen.dart';
import 'user_profile_screen.dart';
import 'widgets/candidate_dashboard_tab.dart';

class UserDashboardScreen extends ConsumerStatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  ConsumerState<UserDashboardScreen> createState() =>
      _UserDashboardScreenState();
}

class _UserDashboardScreenState extends ConsumerState<UserDashboardScreen> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final unreadCount =
        ref
            .watch(candidateNotificationControllerProvider)
            .asData
            ?.value
            .summary
            .unread ??
        0;
    final tabs = [
      CandidateDashboardTab(onSelectTab: _selectTab),
      const UserJobsScreen(),
      const CandidateNotificationsScreen(),
      const UserProfileScreen(),
      const DigitalWalletScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: strings.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.article_outlined),
            selectedIcon: const Icon(Icons.article),
            label: strings.postsTabTitle,
          ),
          NavigationDestination(
            icon: _NotificationDestinationIcon(
              selected: false,
              unreadCount: unreadCount,
            ),
            selectedIcon: _NotificationDestinationIcon(
              selected: true,
              unreadCount: unreadCount,
            ),
            label: strings.notifications,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: strings.myProfileTabTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: strings.digitalWallet,
          ),
        ],
      ),
    );
  }
}

class _NotificationDestinationIcon extends StatelessWidget {
  const _NotificationDestinationIcon({
    required this.selected,
    required this.unreadCount,
  });

  final bool selected;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? Icons.notifications : Icons.notifications_none,
    );
    if (unreadCount <= 0) return icon;
    return Badge(
      label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
      child: icon,
    );
  }
}
