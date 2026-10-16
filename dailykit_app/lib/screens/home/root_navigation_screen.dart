import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/offline_sync_queue.dart';

import '../habits/habits_screen.dart';
import '../expenses/expenses_screen.dart';
import '../items/items_screen.dart';
import '../settings/settings_screen.dart';

class RootNavigationScreen extends StatefulWidget {
  const RootNavigationScreen({super.key});

  @override
  State<RootNavigationScreen> createState() => _RootNavigationScreenState();
}

class _RootNavigationScreenState extends State<RootNavigationScreen> {
  int _currentIndex = 0;
  int _pendingOfflineCount = 0;

  final List<Widget> _screens = const [
    HabitsScreen(),
    ExpensesScreen(),
    ItemsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkOfflineQueue();
  }

  Future<void> _checkOfflineQueue() async {
    final count = await OfflineSyncQueue.getPendingCount();
    if (mounted) {
      setState(() {
        _pendingOfflineCount = count;
      });
    }
  }

  Future<void> _triggerManualSync() async {
    final synced = await OfflineSyncQueue.syncAll();
    await _checkOfflineQueue();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced $synced pending items to cloud!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_pendingOfflineCount > 0)
            MaterialBanner(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              content: Text(
                '$_pendingOfflineCount pending offline action(s) stored locally.',
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              backgroundColor: AppColors.accent,
              actions: [
                TextButton(
                  onPressed: _triggerManualSync,
                  child: const Text('SYNC NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          _checkOfflineQueue();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.check_circle_rounded, color: AppColors.primary),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded, color: AppColors.primary),
            label: 'Where Kept',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
