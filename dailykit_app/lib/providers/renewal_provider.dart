import 'package:flutter/material.dart';
import '../core/database/local_database_service.dart';
import '../core/utils/notification_service.dart';
import '../models/renewal_model.dart';

class RenewalProvider extends ChangeNotifier {
  final LocalDatabaseService _localDb = LocalDatabaseService();

  List<RenewalModel> _renewals = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCategoryFilter = 'All';
  String _selectedStatusFilter = 'All';

  List<RenewalModel> get renewals => _renewals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategoryFilter => _selectedCategoryFilter;
  String get selectedStatusFilter => _selectedStatusFilter;

  int get expiringSoonCount =>
      _renewals.where((r) => r.status == 'expiring_soon' && !r.isRenewed).length;

  // 1. Fetch Renewals directly from SQLite
  Future<void> fetchRenewals({bool refresh = false}) async {
    if (_renewals.isEmpty || refresh) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final list = await _localDb.getRenewals(
        category: _selectedCategoryFilter,
        status: _selectedStatusFilter,
      );
      _renewals = list.map((item) => RenewalModel.fromJson(item)).toList();
      _errorMessage = null;

      // Check for 5, 3, 1 day notifications
      _checkAndTriggerNotifications();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Add Renewal / Warranty to SQLite
  Future<bool> addRenewal({
    required String title,
    required String category,
    String? purchaseDate,
    required String expiryDate,
    double? amount,
    String? notes,
    String remindBeforeDays = '5,3,1',
  }) async {
    try {
      final createdMap = await _localDb.createRenewal(
        title: title,
        category: category,
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
        amount: amount,
        notes: notes,
        remindBeforeDays: remindBeforeDays,
      );

      final created = RenewalModel.fromJson(createdMap);
      _renewals.insert(0, created);
      _renewals.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

      // Schedule instant alert if expiring soon
      if (created.daysRemaining <= 5 && created.daysRemaining >= 0) {
        NotificationService().showInstantNotification(
          id: created.id,
          title: '⚠️ Expiring Soon: ${created.title}',
          body: '${created.category} will expire in ${created.daysRemaining} days on ${created.expiryDate}.',
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // 3. Update Renewal in SQLite
  Future<bool> updateRenewal({
    required int id,
    required String title,
    required String category,
    String? purchaseDate,
    required String expiryDate,
    double? amount,
    String? notes,
    String? remindBeforeDays,
    bool? isRenewed,
  }) async {
    try {
      final updatedMap = await _localDb.updateRenewal(
        id: id,
        title: title,
        category: category,
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
        amount: amount,
        notes: notes,
        remindBeforeDays: remindBeforeDays,
        isRenewed: isRenewed,
      );

      final updated = RenewalModel.fromJson(updatedMap);
      final idx = _renewals.indexWhere((r) => r.id == id);
      if (idx != -1) {
        _renewals[idx] = updated;
        _renewals.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // 4. Delete Renewal in SQLite
  Future<bool> deleteRenewal(int id) async {
    try {
      await _localDb.deleteRenewal(id);
      _renewals.removeWhere((r) => r.id == id);
      NotificationService().cancelNotification(id);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Set Filters
  void setCategoryFilter(String category) {
    _selectedCategoryFilter = category;
    fetchRenewals(refresh: true);
  }

  void setStatusFilter(String status) {
    _selectedStatusFilter = status;
    fetchRenewals(refresh: true);
  }

  // 5. Trigger notifications for 5, 3, and 1 days before expiry
  void _checkAndTriggerNotifications() {
    for (final item in _renewals) {
      if (item.isRenewed) continue;

      final alertDays = item.remindBeforeDays
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();

      if (alertDays.contains(item.daysRemaining) && item.daysRemaining >= 0) {
        String urgency = item.daysRemaining == 1 ? '🚨 FINAL REMINDER' : '⏰ Reminder';
        String dayText = item.daysRemaining == 0
            ? 'expires TODAY'
            : 'expires in ${item.daysRemaining} day${item.daysRemaining > 1 ? 's' : ''}';

        NotificationService().showInstantNotification(
          id: item.id * 10 + item.daysRemaining,
          title: '$urgency: ${item.title}',
          body: '${item.category} $dayText (${item.expiryDate}). Please renew/take action.',
        );
      }
    }
  }
}
