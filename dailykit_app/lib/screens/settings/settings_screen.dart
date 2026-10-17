import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/offline_sync_queue.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // User Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      user != null && user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Appearance Section
          const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark Theme'),
                  subtitle: const Text('Toggle light or dark mode'),
                  secondary: Icon(
                    settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: AppColors.primary,
                  ),
                  value: settings.isDarkMode,
                  onChanged: (val) => settings.toggleDarkMode(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Currency Preference Section
          const Text('Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.currency_exchange_rounded, color: AppColors.primary),
                  title: const Text('Currency'),
                  subtitle: Text('Current: ${settings.currency}'),
                  trailing: DropdownButton<String>(
                    value: settings.currency,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                      DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        settings.setCurrency(val);
                        auth.updateCurrency(val);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_rounded, color: AppColors.secondary),
                  title: const Text('Sync Offline Data'),
                  subtitle: const Text('Upload pending offline check-ins & expenses'),
                  onTap: () async {
                    final count = await OfflineSyncQueue.syncAll();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Offline sync finished. Synced $count items.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About App Card
          Card(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              title: const Text('HEW', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Habits • Expenses • Where Kept • Renewals\nVersion 1.0.0'),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

