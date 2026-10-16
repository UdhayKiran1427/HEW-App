/**
 * Calculate current streak and longest streak from an array of date strings (YYYY-MM-DD).
 * @param {string[]} logDates - Array of dates when the habit was completed (sorted or unsorted)
 * @returns {{ currentStreak: number, longestStreak: number }}
 */
function calculateStreaks(logDates) {
  if (!logDates || logDates.length === 0) {
    return { currentStreak: 0, longestStreak: 0 };
  }

  // Filter out invalid/empty, format to YYYY-MM-DD and deduplicate
  const uniqueDates = Array.from(
    new Set(
      logDates
        .filter(Boolean)
        .map(d => (typeof d === 'string' ? d.substring(0, 10) : new Date(d).toISOString().substring(0, 10)))
    )
  ).sort();

  if (uniqueDates.length === 0) {
    return { currentStreak: 0, longestStreak: 0 };
  }

  // Helper to get formatted string for Date object
  const formatDate = (date) => {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  };

  const dateSet = new Set(uniqueDates);

  // 1. Calculate Current Streak
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);

  const todayStr = formatDate(today);
  const yesterdayStr = formatDate(yesterday);

  let currentStreak = 0;
  let cursor = new Date();

  // If today is completed, streak starts today.
  // If today is NOT completed yet, streak is maintained if yesterday was completed.
  if (dateSet.has(todayStr)) {
    cursor = today;
  } else if (dateSet.has(yesterdayStr)) {
    cursor = yesterday;
  } else {
    currentStreak = 0;
    cursor = null;
  }

  if (cursor) {
    while (true) {
      const cursorStr = formatDate(cursor);
      if (dateSet.has(cursorStr)) {
        currentStreak++;
        cursor.setDate(cursor.getDate() - 1);
      } else {
        break;
      }
    }
  }

  // 2. Calculate Longest Streak
  let longestStreak = 0;
  let tempStreak = 0;
  let prevDate = null;

  for (const dateStr of uniqueDates) {
    const currentDate = new Date(dateStr + 'T00:00:00');
    if (!prevDate) {
      tempStreak = 1;
    } else {
      const diffTime = currentDate.getTime() - prevDate.getTime();
      const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));

      if (diffDays === 1) {
        tempStreak++;
      } else {
        tempStreak = 1;
      }
    }

    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }
    prevDate = currentDate;
  }

  return { currentStreak, longestStreak };
}

module.exports = { calculateStreaks };

