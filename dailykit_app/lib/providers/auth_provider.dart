import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_endpoints.dart';
import '../models/user_model.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;

  // Initialize and check persistent token
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final token = await _apiClient.getToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final response = await _apiClient.dio.get(ApiEndpoints.profile);
      if (response.statusCode == 200 && response.data['success'] == true) {
        _user = UserModel.fromJson(response.data['data']['user']);
        _status = AuthStatus.authenticated;
      } else {
        await _apiClient.deleteToken();
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      // If server unreachable, check if we have cached token to allow offline access
      _status = AuthStatus.authenticated; // Optimistic offline login
    }
    notifyListeners();
  }

  // Login
  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      if (response.data['success'] == true) {
        final token = response.data['data']['token'];
        _user = UserModel.fromJson(response.data['data']['user']);
        await _apiClient.saveToken(token);
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.data['message'] ?? 'Login failed.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } on DioException catch (e) {
      _errorMessage = e.message ?? 'An error occurred during login.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Register
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String currency = 'INR',
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.register,
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'currency': currency,
        },
      );

      if (response.data['success'] == true) {
        final token = response.data['data']['token'];
        _user = UserModel.fromJson(response.data['data']['user']);
        await _apiClient.saveToken(token);
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.data['message'] ?? 'Registration failed.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } on DioException catch (e) {
      _errorMessage = e.message ?? 'Registration error.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Update Currency
  Future<bool> updateCurrency(String newCurrency) async {
    try {
      final response = await _apiClient.dio.put(
        ApiEndpoints.updateCurrency,
        data: {'currency': newCurrency},
      );
      if (response.data['success'] == true && _user != null) {
        _user = _user!.copyWith(currency: newCurrency);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  // Logout
  Future<void> logout() async {
    await _apiClient.deleteToken();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}

