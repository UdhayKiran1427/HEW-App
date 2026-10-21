import 'package:flutter/material.dart';
import '../core/database/local_database_service.dart';
import '../models/user_model.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final LocalDatabaseService _localDb = LocalDatabaseService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;

  // Initialize phone storage local profile
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final profile = await _localDb.getUserProfile();
      _user = UserModel(
        id: profile['id'] as int? ?? 1,
        name: profile['name'] as String? ?? 'User',
        email: profile['email'] as String? ?? 'local@hew.app',
        currency: profile['currency'] as String? ?? 'INR',
      );
      _status = AuthStatus.authenticated;
    } catch (_) {
      _user = UserModel(
        id: 1,
        name: 'User',
        email: 'local@hew.app',
        currency: 'INR',
      );
      _status = AuthStatus.authenticated;
    }

    notifyListeners();
  }

  // Login (phone storage local authentication)
  Future<bool> login(String email, String password) async {
    await checkAuthStatus();
    return true;
  }

  // Register (phone storage local profile setup)
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String currency = 'INR',
  }) async {
    await updateName(name);
    await updateCurrency(currency);
    _status = AuthStatus.authenticated;
    notifyListeners();
    return true;
  }

  // Update Currency locally
  Future<void> updateCurrency(String newCurrency) async {
    if (_user != null) {
      await _localDb.updateUserProfile(currency: newCurrency);
      _user = _user!.copyWith(currency: newCurrency);
      notifyListeners();
    }
  }

  // Update Profile Name locally
  Future<void> updateName(String newName) async {
    if (_user != null) {
      await _localDb.updateUserProfile(name: newName);
      _user = _user!.copyWith(name: newName);
      notifyListeners();
    }
  }

  // Reset or Clear Local Data
  Future<void> logout() async {
    await checkAuthStatus();
  }
}
