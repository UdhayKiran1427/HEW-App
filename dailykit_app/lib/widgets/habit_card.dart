import 'package:flutter/material.dart';
import '../models/habit_model.dart';
import '../core/constants/app_colors.dart';

class HabitCard extends StatelessWidget {
  final HabitModel habit;
  final VoidCallback onCheckIn;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onCheckIn,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final habitColor = AppColors.fromHex(habit.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Habit Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: habitColor.withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  HabitModel.getIconData(habit.icon),
                  color: habitColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Habit Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: habit.isCompletedToday ? TextDecoration.lineThrough : null,
                        color: habit.isCompletedToday ? Colors.grey : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Streak Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                '${habit.currentStreak} d streak',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Best Streak
                        Text(
                          'Best: ${habit.longestStreak}d',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // One-Tap Check-In Button
              InkWell(
                onTap: onCheckIn,
                borderRadius: BorderRadius.circular(30),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: habit.isCompletedToday ? habitColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: habit.isCompletedToday ? habitColor : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: habit.isCompletedToday
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                ),
              ),

              // More options menu (edit/delete)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

