import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/offline_sync_queue.dart';
import '../core/utils/notification_service.dart';
import '../models/habit_model.dart';

class HabitProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  List<HabitModel> _habits = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<HabitModel> get habits => _habits;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 1. Fetch Habits List
  Future<void> fetchHabits({bool refresh = false}) async {
    if (_habits.isEmpty || refresh) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final response = await _apiClient.dio.get(ApiEndpoints.habits);
      if (response.data['success'] == true) {
        final List list = response.data['data']['habits'];
        _habits = list.map((item) => HabitModel.fromJson(item)).toList();
        _errorMessage = null;
      }
    } on DioException catch (e) {
      _errorMessage = e.message ?? 'Failed to load habits.';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. One-Tap Check-In Toggle (Optimistic Update + Offline Queue)
  Future<void> toggleCheckIn(int habitId, {String? date}) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;

    final targetDate = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final currentHabit = _habits[index];
    final bool newStatus = !currentHabit.isCompletedToday;

    // Optimistic UI update
    final int newStreak = newStatus
        ? currentHabit.currentStreak + 1
        : (currentHabit.currentStreak > 0 ? currentHabit.currentStreak - 1 : 0);
    final int newLongest = newStreak > currentHabit.longestStreak ? newStreak : currentHabit.longestStreak;

    _habits[index] = currentHabit.copyWith(
      isCompletedToday: newStatus,
      currentStreak: newStreak,
      longestStreak: newLongest,
      totalCompletions: newStatus ? currentHabit.totalCompletions + 1 : currentHabit.totalCompletions - 1,
    );
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.habitCheckIn(habitId),
        data: {'date': targetDate},
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        _habits[index] = _habits[index].copyWith(
          isCompletedToday: data['is_completed'] as bool,
          currentStreak: data['current_streak'] as int,
          longestStreak: data['longest_streak'] as int,
        );
        notifyListeners();
      }
    } catch (_) {
      // Network offline or failed: save to local offline queue for sync
      await OfflineSyncQueue.queueHabitCheckIn(
        habitId: habitId,
        date: targetDate,
        completed: newStatus,
      );
    }
  }

  // 3. Create Habit
  Future<bool> createHabit({
    required String name,
    required String icon,
    required String color,
    required int targetDaysPerWeek,
    String? reminderTime,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.habits,
        data: {
          'name': name.trim(),
          'icon': icon,
          'color': color,
          'target_days_per_week': targetDaysPerWeek,
          'reminder_time': reminderTime,
        },
      );

      if (response.data['success'] == true) {
        final created = HabitModel.fromJson(response.data['data']['habit']);
        _habits.insert(0, created);

        // Schedule notification if reminder time provided
        if (reminderTime != null) {
          NotificationService().showInstantNotification(
            id: created.id,
            title: 'Habit Reminder: ${created.name}',
            body: "Time to complete your habit today! Keep your streak going 🔥",
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

  // 4. Update Habit
  Future<bool> updateHabit({
    required int habitId,
    required String name,
    required String icon,
    required String color,
    required int targetDaysPerWeek,
    String? reminderTime,
  }) async {
    try {
      final response = await _apiClient.dio.put(
        ApiEndpoints.habitDetails(habitId),
        data: {
          'name': name.trim(),
          'icon': icon,
          'color': color,
          'target_days_per_week': targetDaysPerWeek,
          'reminder_time': reminderTime,
        },
      );

      if (response.data['success'] == true) {
        final index = _habits.indexWhere((h) => h.id == habitId);
        if (index != -1) {
          _habits[index] = _habits[index].copyWith(
            name: name,
            icon: icon,
            color: color,
            targetDaysPerWeek: targetDaysPerWeek,
            reminderTime: reminderTime,
          );
          notifyListeners();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  // 5. Delete Habit
  Future<bool> deleteHabit(int habitId) async {
    try {
      final response = await _apiClient.dio.delete(ApiEndpoints.habitDetails(habitId));
      if (response.data['success'] == true) {
        _habits.removeWhere((h) => h.id == habitId);
        NotificationService().cancelNotification(habitId);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  // 6. Fetch Full Habit Details (with all completion logs for heatmap)
  Future<HabitModel?> fetchHabitDetails(int habitId) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.habitDetails(habitId));
      if (response.data['success'] == true) {
        return HabitModel.fromJson(response.data['data']['habit']);
      }
    } catch (_) {}
    return null;
  }
}

