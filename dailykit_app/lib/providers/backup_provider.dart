import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/services/cloud_backup_service.dart';
import 'auth_provider.dart';
import 'expense_provider.dart';
import 'habit_provider.dart';
import 'item_provider.dart';
import 'renewal_provider.dart';

class BackupProvider extends ChangeNotifier {
  final CloudBackupService _backupService = CloudBackupService();

  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _lastBackupTimeStr;
  String? _lastBackupAccount;
  String? _statusMessage;

  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;
  String? get lastBackupTimeStr => _lastBackupTimeStr;
  String? get lastBackupAccount => _lastBackupAccount;
  String? get statusMessage => _statusMessage;
  String? get userEmail => _backupService.currentUser?.email;

  BackupProvider() {
    loadLastBackupInfo();
  }

  Future<void> loadLastBackupInfo() async {
    final info = await _backupService.getLastBackupInfo();
    final rawTime = info['time'];
    if (rawTime != null) {
      try {
        final dt = DateTime.parse(rawTime);
        _lastBackupTimeStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      } catch (_) {
        _lastBackupTimeStr = rawTime;
      }
    }
    _lastBackupAccount = info['account'];
    notifyListeners();
  }

  // Refresh all providers after restore
  Future<void> _refreshAllProviders(BuildContext context) async {
    if (!context.mounted) return;
    try {
      await Future.wait([
        context.read<HabitProvider>().fetchHabits(refresh: true),
        context.read<ExpenseProvider>().fetchExpenses(refresh: true),
        context.read<ExpenseProvider>().fetchCategories(),
        context.read<ItemProvider>().fetchItems(refresh: true),
        context.read<RenewalProvider>().fetchRenewals(refresh: true),
        context.read<AuthProvider>().checkAuthStatus(),
      ]);
    } catch (e) {
      debugPrint('Error refreshing providers after restore: $e');
    }
  }

  // 1. Direct Google Drive Backup
  Future<Map<String, dynamic>> backupToDrive(BuildContext context) async {
    _isBackingUp = true;
    _statusMessage = 'Connecting to Google Drive...';
    notifyListeners();

    try {
      final res = await _backupService.backupToGoogleDrive();
      await loadLastBackupInfo();
      _statusMessage = 'Backup completed successfully!';
      return res;
    } catch (e) {
      _statusMessage = 'Error: $e';
      rethrow;
    } finally {
      _isBackingUp = false;
      notifyListeners();
    }
  }

  // 2. Direct Google Drive Restore
  Future<Map<String, dynamic>> restoreFromDrive(BuildContext context) async {
    _isRestoring = true;
    _statusMessage = 'Restoring data from Google Drive...';
    notifyListeners();

    try {
      final res = await _backupService.restoreFromGoogleDrive();
      if (context.mounted) {
        await _refreshAllProviders(context);
      }
      _statusMessage = 'Restore completed successfully!';
      return res;
    } catch (e) {
      _statusMessage = 'Error: $e';
      rethrow;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  // 3. Export & Share Backup File (Save to Google Drive / WhatsApp / Files)
  Future<void> exportAndShare() async {
    _isBackingUp = true;
    notifyListeners();
    try {
      await _backupService.exportAndShareBackup();
      await loadLastBackupInfo();
    } finally {
      _isBackingUp = false;
      notifyListeners();
    }
  }

  // 4. Restore from Picked Backup File (.json)
  Future<Map<String, dynamic>> restoreFromFile(BuildContext context) async {
    _isRestoring = true;
    notifyListeners();
    try {
      final res = await _backupService.restoreFromLocalFile();
      if (context.mounted) {
        await _refreshAllProviders(context);
      }
      return res;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }
}

