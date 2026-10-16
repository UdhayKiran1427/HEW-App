import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarHeatmap extends StatelessWidget {
  final List<String> completedDates; // List of 'YYYY-MM-DD'
  final Color habitColor;
  final DateTime targetMonth;

  const CalendarHeatmap({
    super.key,
    required this.completedDates,
    required this.habitColor,
    required this.targetMonth,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(targetMonth.year, targetMonth.month);
    final firstDayOfWeek = DateTime(targetMonth.year, targetMonth.month, 1).weekday; // 1 = Mon, 7 = Sun
    final offset = firstDayOfWeek - 1; // 0 for Monday

    final completedSet = Set<String>.from(completedDates);
    final monthName = DateFormat('MMMM yyyy').format(targetMonth);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  monthName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${completedSet.length} days done',
                  style: TextStyle(color: habitColor, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Weekday labels (Mon to Sun)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _WeekdayLabel('M'),
                _WeekdayLabel('T'),
                _WeekdayLabel('W'),
                _WeekdayLabel('T'),
                _WeekdayLabel('F'),
                _WeekdayLabel('S'),
                _WeekdayLabel('S'),
              ],
            ),
            const SizedBox(height: 8),

            // Days Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1,
              ),
              itemCount: offset + daysInMonth,
              itemBuilder: (context, index) {
                if (index < offset) {
                  return const SizedBox.shrink(); // Empty slot before first day
                }

                final day = index - offset + 1;
                final dateStr =
                    '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                final isDone = completedSet.contains(dateStr);

                final isToday = DateTime.now().year == targetMonth.year &&
                    DateTime.now().month == targetMonth.month &&
                    DateTime.now().day == day;

                return Container(
                  decoration: BoxDecoration(
                    color: isDone ? habitColor : (isToday ? habitColor.withAlpha(30) : Colors.black.withAlpha(10)),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday ? Border.all(color: habitColor, width: 1.5) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isDone || isToday ? FontWeight.bold : FontWeight.normal,
                      color: isDone
                          ? Colors.white
                          : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;
  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
        ),
      ),
    );
  }
}
