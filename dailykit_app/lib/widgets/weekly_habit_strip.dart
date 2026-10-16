import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklyHabitStrip extends StatelessWidget {
  final List<String> completedLogs;
  final Color habitColor;
  final Function(String date)? onDateTap;

  const WeeklyHabitStrip({
    super.key,
    required this.completedLogs,
    required this.habitColor,
    this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Find Monday of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final completedSet = Set<String>.from(completedLogs);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final day = monday.add(Duration(days: index));
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        final dayLetter = DateFormat('E').format(day)[0]; // M, T, W...
        final isDone = completedSet.contains(dateStr);
        final isToday = day.year == now.year && day.month == now.month && day.day == now.day;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onDateTap?.call(dateStr),
          child: Column(
            children: [
              Text(
                dayLetter,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isToday ? habitColor : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone ? habitColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone
                        ? habitColor
                        : (isToday ? habitColor : Colors.grey.shade300),
                    width: isToday ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                                ? habitColor
                                : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

