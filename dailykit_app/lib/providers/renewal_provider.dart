import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_endpoints.dart';
import '../core/utils/notification_service.dart';
import '../models/renewal_model.dart';

class RenewalProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

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

  // 1. Fetch Renewals
  Future<void> fetchRenewals({bool refresh = false}) async {
    if (_renewals.isEmpty || refresh) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final Map<String, dynamic> params = {};
      if (_selectedCategoryFilter != 'All') {
        params['category'] = _selectedCategoryFilter;
      }
      if (_selectedStatusFilter != 'All') {
        params['status'] = _selectedStatusFilter.toLowerCase().replaceAll(' ', '_');
      }

      final response = await _apiClient.dio.get(
        ApiEndpoints.renewals,
        queryParameters: params,
      );

      if (response.data['success'] == true) {
        final List list = response.data['data']['renewals'];
        _renewals = list.map((item) => RenewalModel.fromJson(item)).toList();
        _errorMessage = null;

        // Check for 5, 3, 1 day notifications
        _checkAndTriggerNotifications();
      }
    } on DioException catch (e) {
      _errorMessage = e.message ?? 'Failed to load renewals.';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Add Renewal / Warranty
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
      final response = await _apiClient.dio.post(
        ApiEndpoints.renewals,
        data: {
          'title': title.trim(),
          'category': category,
          'purchase_date': purchaseDate,
          'expiry_date': expiryDate,
          'amount': amount,
          'notes': notes,
          'remind_before_days': remindBeforeDays,
        },
      );

      if (response.data['success'] == true) {
        final created = RenewalModel.fromJson(response.data['data']['renewal']);
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
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    return false;
  }

  // 3. Update Renewal
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
      final response = await _apiClient.dio.put(
        ApiEndpoints.renewalItem(id),
        data: {
          'title': title.trim(),
          'category': category,
          'purchase_date': purchaseDate,
          'expiry_date': expiryDate,
          'amount': amount,
          'notes': notes,
          'remind_before_days': remindBeforeDays,
          'is_renewed': isRenewed,
        },
      );

      if (response.data['success'] == true) {
        final updated = RenewalModel.fromJson(response.data['data']['renewal']);
        final idx = _renewals.indexWhere((r) => r.id == id);
        if (idx != -1) {
          _renewals[idx] = updated;
          _renewals.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
          notifyListeners();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  // 4. Delete Renewal
  Future<bool> deleteRenewal(int id) async {
    try {
      final response = await _apiClient.dio.delete(ApiEndpoints.renewalItem(id));
      if (response.data['success'] == true) {
        _renewals.removeWhere((r) => r.id == id);
        NotificationService().cancelNotification(id);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
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

      // Check if current days remaining matches 5, 3, or 1
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

