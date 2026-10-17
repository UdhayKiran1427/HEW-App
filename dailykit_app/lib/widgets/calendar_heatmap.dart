import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarHeatmap extends StatelessWidget {
  final List<String> completedDates; // List of 'YYYY-MM-DD'
  final Color habitColor;
  final DateTime targetMonth;
  final ValueChanged<DateTime>? onMonthChanged;
  final ValueChanged<String>? onDateTap;

  const CalendarHeatmap({
    super.key,
    required this.completedDates,
    required this.habitColor,
    required this.targetMonth,
    this.onMonthChanged,
    this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(targetMonth.year, targetMonth.month);
    final firstDayOfWeek = DateTime(targetMonth.year, targetMonth.month, 1).weekday; // 1 = Mon, 7 = Sun
    final offset = firstDayOfWeek - 1; // 0 for Monday

    final completedSet = Set<String>.from(completedDates);
    final monthName = DateFormat('MMMM yyyy').format(targetMonth);

    // Filter completions strictly in this targetMonth
    final prefix = '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';
    final monthDoneCount = completedDates.where((d) => d.startsWith(prefix)).length;
    final percentage = daysInMonth > 0 ? (monthDoneCount / daysInMonth * 100).toStringAsFixed(0) : '0';

    final now = DateTime.now();
    final isCurrentMonth = now.year == targetMonth.year && now.month == targetMonth.month;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Header with Prev & Next Arrows
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (onMonthChanged != null)
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Previous Month',
                        onPressed: () {
                          final prev = DateTime(targetMonth.year, targetMonth.month - 1, 1);
                          onMonthChanged!(prev);
                        },
                      ),
                    const SizedBox(width: 6),
                    Text(
                      monthName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    if (onMonthChanged != null)
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Next Month',
                        onPressed: () {
                          final next = DateTime(targetMonth.year, targetMonth.month + 1, 1);
                          onMonthChanged!(next);
                        },
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: habitColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$monthDoneCount / $daysInMonth days ($percentage%)',
                    style: TextStyle(
                      color: habitColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

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

                final isToday = isCurrentMonth && now.day == day;
                final isFuture = targetMonth.year > now.year ||
                    (targetMonth.year == now.year && targetMonth.month > now.month) ||
                    (isCurrentMonth && day > now.day);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: isFuture
                        ? null
                        : () {
                            if (onDateTap != null) {
                              onDateTap!(dateStr);
                            }
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDone
                            ? habitColor
                            : (isToday
                                ? habitColor.withAlpha(35)
                                : (isFuture
                                    ? Colors.black.withAlpha(5)
                                    : Colors.black.withAlpha(12))),
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: habitColor, width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isDone || isToday ? FontWeight.bold : FontWeight.normal,
                              color: isDone
                                  ? Colors.white
                                  : (isFuture
                                      ? Colors.grey.shade400
                                      : (Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white70
                                          : Colors.black87)),
                            ),
                          ),
                          if (isDone)
                            Positioned(
                              bottom: 2,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '💡 Tap any day to toggle check-in',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
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
