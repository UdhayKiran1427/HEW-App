import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  // Dynamically detect host: 10.0.2.2 for Android emulator, localhost for Web/Windows/iOS
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    if (Platform.isAndroid) {
      // 192.168.1.68 allows your physical phone to connect directly to the backend
      return 'http://192.168.1.68:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/profile';
  static const String updateCurrency = '/auth/currency';

  // Habits
  static const String habits = '/habits';
  static String habitDetails(int id) => '/habits/$id';
  static String habitCheckIn(int id) => '/habits/$id/check-in';
  static const String habitsSyncBatch = '/habits/sync/batch';

  // Expenses
  static const String expenses = '/expenses';
  static const String categories = '/expenses/categories';
  static const String expenseReports = '/expenses/reports/summary';
  static String expenseItem(int id) => '/expenses/$id';
  static const String expensesSyncBatch = '/expenses/sync/batch';

  // Where I Kept It (Items)
  static const String items = '/items';
  static String itemDetails(int id) => '/items/$id';
  static String moveItem(int id) => '/items/$id/move';
}

