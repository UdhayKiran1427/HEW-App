import 'package:flutter/material.dart';
import '../core/database/local_database_service.dart';
import '../core/utils/notification_service.dart';
import '../models/habit_model.dart';

class HabitProvider extends ChangeNotifier {
  final LocalDatabaseService _localDb = LocalDatabaseService();

  List<HabitModel> _habits = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<HabitModel> get habits => _habits;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 1. Fetch Habits List directly from phone storage (SQLite)
  Future<void> fetchHabits({bool refresh = false}) async {
    if (_habits.isEmpty || refresh) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final list = await _localDb.getHabits();
      _habits = list.map((item) => HabitModel.fromJson(item)).toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. One-Tap Check-In Toggle in SQLite
  Future<void> toggleCheckIn(int habitId, {String? date}) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;

    try {
      await _localDb.toggleHabitCheckIn(habitId, date: date);
      // Refresh details to recompute streak accurately
      final detailed = await _localDb.getHabitDetails(habitId);
      if (detailed != null) {
        _habits[index] = HabitModel.fromJson(detailed);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // 3. Create Habit in SQLite
  Future<bool> createHabit({
    required String name,
    required String icon,
    required String color,
    required int targetDaysPerWeek,
    String? reminderTime,
  }) async {
    try {
      final createdMap = await _localDb.createHabit(
        name: name,
        icon: icon,
        color: color,
        targetDaysPerWeek: targetDaysPerWeek,
        reminderTime: reminderTime,
      );

      final created = HabitModel.fromJson(createdMap);
      _habits.insert(0, created);

      // Schedule local notification if reminder time provided
      if (reminderTime != null) {
        NotificationService().showInstantNotification(
          id: created.id,
          title: 'Habit Reminder: ${created.name}',
          body: "Time to complete your habit today! Keep your streak going 🔥",
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
    }
    return false;
  }

  // 4. Update Habit in SQLite
  Future<bool> updateHabit({
    required int habitId,
    required String name,
    required String icon,
    required String color,
    required int targetDaysPerWeek,
    String? reminderTime,
  }) async {
    try {
      await _localDb.updateHabit(
        habitId: habitId,
        name: name,
        icon: icon,
        color: color,
        targetDaysPerWeek: targetDaysPerWeek,
        reminderTime: reminderTime,
      );

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
    } catch (e) {
      _errorMessage = e.toString();
    }
    return false;
  }

  // 5. Delete Habit in SQLite
  Future<bool> deleteHabit(int habitId) async {
    try {
      await _localDb.deleteHabit(habitId);
      _habits.removeWhere((h) => h.id == habitId);
      NotificationService().cancelNotification(habitId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
    }
    return false;
  }

  // 6. Fetch Full Habit Details (with all completion logs for heatmap)
  Future<HabitModel?> fetchHabitDetails(int habitId) async {
    try {
      final detailed = await _localDb.getHabitDetails(habitId);
      if (detailed != null) {
        return HabitModel.fromJson(detailed);
      }
    } catch (_) {}
    return null;
  }
}
