const pool = require('../config/db');
const { calculateStreaks } = require('../utils/streakCalculator');

// Helper to format Date to YYYY-MM-DD
const formatDate = (d) => {
  const date = new Date(d);
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

// 1. Get all active habits for the logged-in user with today's status & streaks
const getHabits = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const todayStr = formatDate(new Date());

    // Fetch all habits for user
    const [habits] = await pool.query(
      `SELECT id, user_id, name, icon, color, target_days_per_week, reminder_time, is_archived, created_at
       FROM habits
       WHERE user_id = ? AND is_archived = FALSE
       ORDER BY id ASC`,
      [userId]
    );

    if (habits.length === 0) {
      return res.json({ success: true, data: { habits: [] } });
    }

    const habitIds = habits.map(h => h.id);

    // Fetch all habit logs for this user to calculate streaks and status
    const [allLogs] = await pool.query(
      `SELECT habit_id, log_date, completed
       FROM habit_logs
       WHERE user_id = ? AND habit_id IN (?) AND completed = TRUE
       ORDER BY log_date ASC`,
      [userId, habitIds]
    );

    // Group logs by habit_id
    const logsByHabit = {};
    for (const hId of habitIds) {
      logsByHabit[hId] = [];
    }
    for (const log of allLogs) {
      if (logsByHabit[log.habit_id]) {
        logsByHabit[log.habit_id].push(log.log_date);
      }
    }

    // Attach streaks, completed_today, and weekly completion
    const enrichedHabits = habits.map(habit => {
      const dates = logsByHabit[habit.id] || [];
      const { currentStreak, longestStreak } = calculateStreaks(dates);
      const isCompletedToday = dates.includes(todayStr);

      return {
        ...habit,
        is_completed_today: isCompletedToday,
        current_streak: currentStreak,
        longest_streak: longestStreak,
        total_completions: dates.length
      };
    });

    return res.json({
      success: true,
      data: {
        today: todayStr,
        habits: enrichedHabits
      }
    });
  } catch (error) {
    next(error);
  }
};

// 2. Get single habit details (weekly view + monthly heatmap logs)
const getHabitDetails = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const habitId = req.params.id;

    const [habits] = await pool.query(
      'SELECT * FROM habits WHERE id = ? AND user_id = ?',
      [habitId, userId]
    );

    if (habits.length === 0) {
      return res.status(404).json({ success: false, message: 'Habit not found.' });
    }

    const habit = habits[0];

    // Fetch all completion dates for this habit
    const [logs] = await pool.query(
      'SELECT log_date, completed FROM habit_logs WHERE habit_id = ? AND user_id = ? AND completed = TRUE ORDER BY log_date ASC',
      [habitId, userId]
    );

    const completionDates = logs.map(l => l.log_date);
    const { currentStreak, longestStreak } = calculateStreaks(completionDates);

    return res.json({
      success: true,
      data: {
        habit: {
          ...habit,
          current_streak: currentStreak,
          longest_streak: longestStreak,
          total_completions: completionDates.length,
          logs: completionDates // Array of YYYY-MM-DD
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// 3. Create a new habit
const createHabit = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { name, icon = 'check_circle', color = '#4CAF50', target_days_per_week = 7, reminder_time = null } = req.body;

    if (!name || name.trim() === '') {
      return res.status(400).json({ success: false, message: 'Habit name is required.' });
    }

    const [result] = await pool.query(
      `INSERT INTO habits (user_id, name, icon, color, target_days_per_week, reminder_time)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [userId, name.trim(), icon, color, target_days_per_week, reminder_time]
    );

    return res.status(201).json({
      success: true,
      message: 'Habit created successfully.',
      data: {
        habit: {
          id: result.insertId,
          user_id: userId,
          name: name.trim(),
          icon,
          color,
          target_days_per_week,
          reminder_time,
          is_archived: false,
          is_completed_today: false,
          current_streak: 0,
          longest_streak: 0,
          total_completions: 0
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// 4. Update an existing habit
const updateHabit = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const habitId = req.params.id;
    const { name, icon, color, target_days_per_week, reminder_time, is_archived } = req.body;

    const [existing] = await pool.query('SELECT id FROM habits WHERE id = ? AND user_id = ?', [habitId, userId]);
    if (existing.length === 0) {
      return res.status(404).json({ success: false, message: 'Habit not found.' });
    }

    const updates = [];
    const values = [];

    if (name !== undefined) { updates.push('name = ?'); values.push(name.trim()); }
    if (icon !== undefined) { updates.push('icon = ?'); values.push(icon); }
    if (color !== undefined) { updates.push('color = ?'); values.push(color); }
    if (target_days_per_week !== undefined) { updates.push('target_days_per_week = ?'); values.push(target_days_per_week); }
    if (reminder_time !== undefined) { updates.push('reminder_time = ?'); values.push(reminder_time); }
    if (is_archived !== undefined) { updates.push('is_archived = ?'); values.push(is_archived); }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'No fields provided for update.' });
    }

    values.push(habitId, userId);
    await pool.query(`UPDATE habits SET ${updates.join(', ')} WHERE id = ? AND user_id = ?`, values);

    return res.json({
      success: true,
      message: 'Habit updated successfully.'
    });
  } catch (error) {
    next(error);
  }
};

// 5. Delete a habit
const deleteHabit = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const habitId = req.params.id;

    const [result] = await pool.query('DELETE FROM habits WHERE id = ? AND user_id = ?', [habitId, userId]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Habit not found.' });
    }

    return res.json({ success: true, message: 'Habit deleted successfully.' });
  } catch (error) {
    next(error);
  }
};

// 6. One-tap Check-In Toggle (Today or a specific date)
const toggleCheckIn = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const habitId = req.params.id;
    const { date } = req.body; // YYYY-MM-DD, defaults to today
    const targetDate = date ? formatDate(new Date(date)) : formatDate(new Date());

    // Verify habit ownership
    const [habit] = await pool.query('SELECT id FROM habits WHERE id = ? AND user_id = ?', [habitId, userId]);
    if (habit.length === 0) {
      return res.status(404).json({ success: false, message: 'Habit not found.' });
    }

    // Check if log exists
    const [existing] = await pool.query(
      'SELECT id, completed FROM habit_logs WHERE habit_id = ? AND log_date = ?',
      [habitId, targetDate]
    );

    let isCompleted = false;

    if (existing.length > 0) {
      // Toggle state: if was completed, uncomplete (delete or set completed = false)
      if (existing[0].completed) {
        await pool.query('DELETE FROM habit_logs WHERE id = ?', [existing[0].id]);
        isCompleted = false;
      } else {
        await pool.query('UPDATE habit_logs SET completed = TRUE WHERE id = ?', [existing[0].id]);
        isCompleted = true;
      }
    } else {
      // Insert new check-in
      await pool.query(
        'INSERT INTO habit_logs (habit_id, user_id, log_date, completed) VALUES (?, ?, ?, TRUE)',
        [habitId, userId, targetDate]
      );
      isCompleted = true;
    }

    // Recalculate streak
    const [allLogs] = await pool.query(
      'SELECT log_date FROM habit_logs WHERE habit_id = ? AND user_id = ? AND completed = TRUE ORDER BY log_date ASC',
      [habitId, userId]
    );
    const dates = allLogs.map(l => l.log_date);
    const { currentStreak, longestStreak } = calculateStreaks(dates);

    return res.json({
      success: true,
      message: isCompleted ? 'Habit checked in!' : 'Check-in removed.',
      data: {
        habit_id: Number(habitId),
        date: targetDate,
        is_completed: isCompleted,
        current_streak: currentStreak,
        longest_streak: longestStreak
      }
    });
  } catch (error) {
    next(error);
  }
};

// 7. Batch Offline Sync for Habit Logs
const batchSyncHabitLogs = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { logs } = req.body; // Array of { habit_id, date, completed }

    if (!Array.isArray(logs) || logs.length === 0) {
      return res.status(400).json({ success: false, message: 'Logs array is required.' });
    }

    for (const item of logs) {
      const { habit_id, date, completed } = item;
      const targetDate = formatDate(new Date(date));

      if (completed) {
        await pool.query(
          `INSERT INTO habit_logs (habit_id, user_id, log_date, completed)
           VALUES (?, ?, ?, TRUE)
           ON DUPLICATE KEY UPDATE completed = TRUE`,
          [habit_id, userId, targetDate]
        );
      } else {
        await pool.query(
          'DELETE FROM habit_logs WHERE habit_id = ? AND user_id = ? AND log_date = ?',
          [habit_id, userId, targetDate]
        );
      }
    }

    return res.json({
      success: true,
      message: `Successfully synced ${logs.length} habit logs.`
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getHabits,
  getHabitDetails,
  createHabit,
  updateHabit,
  deleteHabit,
  toggleCheckIn,
  batchSyncHabitLogs
};

