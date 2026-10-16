import 'package:flutter/material.dart';

class HabitModel {
  final int id;
  final int userId;
  final String name;
  final String icon;
  final String color;
  final int targetDaysPerWeek;
  final String? reminderTime;
  final bool isArchived;
  final bool isCompletedToday;
  final int currentStreak;
  final int longestStreak;
  final int totalCompletions;
  final List<String> logs; // List of YYYY-MM-DD

  HabitModel({
    required this.id,
    required this.userId,
    required this.name,
    this.icon = 'check_circle',
    this.color = '#4CAF50',
    this.targetDaysPerWeek = 7,
    this.reminderTime,
    this.isArchived = false,
    this.isCompletedToday = false,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalCompletions = 0,
    this.logs = const [],
  });

  factory HabitModel.fromJson(Map<String, dynamic> json) {
    return HabitModel(
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? 'check_circle',
      color: json['color'] as String? ?? '#4CAF50',
      targetDaysPerWeek: json['target_days_per_week'] as int? ?? 7,
      reminderTime: json['reminder_time'] as String?,
      isArchived: json['is_archived'] == 1 || json['is_archived'] == true,
      isCompletedToday: json['is_completed_today'] == 1 || json['is_completed_today'] == true,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      totalCompletions: json['total_completions'] as int? ?? 0,
      logs: json['logs'] != null
          ? List<String>.from(json['logs'].map((x) => x.toString()))
          : [],
    );
  }

  HabitModel copyWith({
    int? id,
    int? userId,
    String? name,
    String? icon,
    String? color,
    int? targetDaysPerWeek,
    String? reminderTime,
    bool? isArchived,
    bool? isCompletedToday,
    int? currentStreak,
    int? longestStreak,
    int? totalCompletions,
    List<String>? logs,
  }) {
    return HabitModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      reminderTime: reminderTime ?? this.reminderTime,
      isArchived: isArchived ?? this.isArchived,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      logs: logs ?? this.logs,
    );
  }

  // Icon mapping helper
  static IconData getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'self_improvement':
        return Icons.self_improvement_rounded;
      case 'bedtime':
        return Icons.bedtime_rounded;
      case 'directions_run':
        return Icons.directions_run_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'music_note':
        return Icons.music_note_rounded;
      case 'brush':
        return Icons.brush_rounded;
      case 'savings':
        return Icons.savings_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }
}

