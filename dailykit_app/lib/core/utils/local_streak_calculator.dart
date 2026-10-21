class StreakResult {
  final int currentStreak;
  final int longestStreak;

  const StreakResult({required this.currentStreak, required this.longestStreak});
}

class LocalStreakCalculator {
  static StreakResult calculate(List<String> completedDates) {
    if (completedDates.isEmpty) {
      return const StreakResult(currentStreak: 0, longestStreak: 0);
    }

    final uniqueDates = completedDates.toSet().toList()..sort();
    final today = _formatDate(DateTime.now());
    final yesterday = _formatDate(DateTime.now().subtract(const Duration(days: 1)));

    // Calculate Longest Streak
    int longest = 0;
    int tempStreak = 0;
    DateTime? prevDate;

    for (final dStr in uniqueDates) {
      final current = DateTime.tryParse(dStr);
      if (current == null) continue;

      if (prevDate == null) {
        tempStreak = 1;
      } else {
        final diff = current.difference(prevDate).inDays;
        if (diff == 1) {
          tempStreak++;
        } else if (diff > 1) {
          tempStreak = 1;
        }
      }
      if (tempStreak > longest) longest = tempStreak;
      prevDate = current;
    }

    // Calculate Current Streak
    int current = 0;
    final dateSet = uniqueDates.toSet();

    if (dateSet.contains(today)) {
      current = 1;
      var checkDate = DateTime.now().subtract(const Duration(days: 1));
      while (dateSet.contains(_formatDate(checkDate))) {
        current++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    } else if (dateSet.contains(yesterday)) {
      current = 1;
      var checkDate = DateTime.now().subtract(const Duration(days: 2));
      while (dateSet.contains(_formatDate(checkDate))) {
        current++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    }

    return StreakResult(
      currentStreak: current,
      longestStreak: longest > current ? longest : current,
    );
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

