import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/backup_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/local_database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _dbSize = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _loadDbSize();
  }

  Future<void> _loadDbSize() async {
    final size = await LocalDatabaseService().getDatabaseSize();
    if (mounted) {
      setState(() {
        _dbSize = size;
      });
    }
  }

  void _openEditNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<AuthProvider>().updateName(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDriveBackup() async {
    final backup = context.read<BackupProvider>();
    try {
      final res = await backup.backupToDrive(context);
      _loadDbSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup saved to Google Drive successfully! (${res['account'] ?? ''})'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showBackupAlternativeDialog(e.toString());
    }
  }

  Future<void> _handleDriveRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Google Drive?'),
        content: const Text(
          'This will restore your habits, expenses, items, and renewals from the latest Google Drive backup. Current local data will be updated.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    final backup = context.read<BackupProvider>();
    try {
      final res = await backup.restoreFromDrive(context);
      _loadDbSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data restored from Google Drive! (${res['summary'] ?? ''})'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not restore from Drive: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleExportShare() async {
    final backup = context.read<BackupProvider>();
    try {
      await backup.exportAndShare();
      _loadDbSize();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleFileRestore() async {
    final backup = context.read<BackupProvider>();
    try {
      final res = await backup.restoreFromFile(context);
      _loadDbSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully restored from ${res['fileName']}!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('No file selected')) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBackupAlternativeDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.cloud_upload_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Google Drive Backup'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Direct Google Drive API sign-in requires Google Play OAuth credentials.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text(
              'Would you like to save your backup directly to Google Drive via Android Share?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'This opens the native Google Drive uploader instantly with 0 setup needed.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
            label: const Text('Save to Google Drive', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(ctx);
              _handleExportShare();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final backup = context.watch<BackupProvider>();
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
                    backgroundColor: AppColors.primary.withAlpha(40),
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
                        const Text(
                          'Phone Local Account • 100% Private',
                          style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _openEditNameDialog(user?.name ?? 'User'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cloud Backup Section (Google Drive)
          const Text('Cloud Backup & Restore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud_sync_rounded, color: Colors.blue, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google Drive Cloud Backup',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              backup.lastBackupTimeStr != null
                                  ? 'Last backup: ${backup.lastBackupTimeStr}'
                                  : 'No cloud backup yet',
                              style: TextStyle(
                                fontSize: 12,
                                color: backup.lastBackupTimeStr != null ? Colors.green : Colors.grey,
                                fontWeight: backup.lastBackupTimeStr != null ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Safely backup your habits, expenses, where-kept items, and renewals to your personal Google Drive like WhatsApp.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  if (backup.isBackingUp || backup.isRestoring)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                            label: const Text('Back Up Now', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _handleDriveBackup,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.cloud_download_rounded, size: 18),
                            label: const Text('Restore', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _handleDriveRestore,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    // Alternative Share / Save to Drive & Pick File
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Save / Share File', style: TextStyle(fontSize: 12)),
                          onPressed: _handleExportShare,
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.file_open_rounded, size: 16),
                          label: const Text('Restore from File', style: TextStyle(fontSize: 12)),
                          onPressed: _handleFileRestore,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Database Storage Section (Phone Storage)
          const Text('Database & Storage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_android_rounded, color: AppColors.primary),
                  title: const Text('Database Engine'),
                  subtitle: const Text('Phone Internal Storage (SQLite)'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '● Active Local',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sd_storage_rounded, color: AppColors.secondary),
                  title: const Text('Local Database Size'),
                  subtitle: Text('$_dbSize on phone storage'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _loadDbSize,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.offline_bolt_rounded, color: Colors.orange),
                  title: const Text('Offline Status'),
                  subtitle: const Text('Works 100% offline with 0s latency & zero servers'),
                ),
              ],
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
              subtitle: const Text('Habits • Expenses • Where Kept • Renewals\nVersion 1.0.0 (Phone Storage SQLite)'),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
