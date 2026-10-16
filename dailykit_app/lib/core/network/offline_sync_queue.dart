import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../constants/api_endpoints.dart';

class OfflineSyncQueue {
  static const String _habitQueueKey = 'offline_habit_queue';
  static const String _expenseQueueKey = 'offline_expense_queue';

  // 1. Habit Check-in Queue
  static Future<void> queueHabitCheckIn({
    required int habitId,
    required String date,
    required bool completed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queue = prefs.getStringList(_habitQueueKey) ?? [];

    final item = jsonEncode({
      'habit_id': habitId,
      'date': date,
      'completed': completed,
      'queued_at': DateTime.now().toIso8601String(),
    });

    queue.add(item);
    await prefs.setStringList(_habitQueueKey, queue);
  }

  // 2. Expense Queue
  static Future<void> queueExpense({
    required int categoryId,
    required double amount,
    required String note,
    required String date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queue = prefs.getStringList(_expenseQueueKey) ?? [];

    final item = jsonEncode({
      'category_id': categoryId,
      'amount': amount,
      'note': note,
      'expense_date': date,
      'queued_at': DateTime.now().toIso8601String(),
    });

    queue.add(item);
    await prefs.setStringList(_expenseQueueKey, queue);
  }

  // 3. Process and sync all pending items
  static Future<int> syncAll() async {
    final prefs = await SharedPreferences.getInstance();
    final dio = ApiClient().dio;
    int syncedCount = 0;

    // A. Sync Habit Check-ins
    final List<String> habitQueue = prefs.getStringList(_habitQueueKey) ?? [];
    if (habitQueue.isNotEmpty) {
      try {
        final List<Map<String, dynamic>> logs = habitQueue
            .map((s) => jsonDecode(s) as Map<String, dynamic>)
            .toList();

        final response = await dio.post(
          ApiEndpoints.habitsSyncBatch,
          data: {'logs': logs},
        );

        if (response.statusCode == 200) {
          syncedCount += logs.length;
          await prefs.remove(_habitQueueKey);
        }
      } catch (_) {
        // Still offline or error, keep in queue
      }
    }

    // B. Sync Expenses
    final List<String> expenseQueue = prefs.getStringList(_expenseQueueKey) ?? [];
    if (expenseQueue.isNotEmpty) {
      try {
        final List<Map<String, dynamic>> expenses = expenseQueue
            .map((s) => jsonDecode(s) as Map<String, dynamic>)
            .toList();

        final response = await dio.post(
          ApiEndpoints.expensesSyncBatch,
          data: {'expenses': expenses},
        );

        if (response.statusCode == 200) {
          syncedCount += expenses.length;
          await prefs.remove(_expenseQueueKey);
        }
      } catch (_) {
        // Still offline or error, keep in queue
      }
    }

    return syncedCount;
  }

  // Get pending count
  static Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final habitCount = (prefs.getStringList(_habitQueueKey) ?? []).length;
    final expenseCount = (prefs.getStringList(_expenseQueueKey) ?? []).length;
    return habitCount + expenseCount;
  }
}

