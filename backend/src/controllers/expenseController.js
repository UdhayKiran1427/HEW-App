const pool = require('../config/db');

// Helper to format Date to YYYY-MM-DD
const formatDate = (d) => {
  const date = new Date(d);
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

// 1. Get Categories (Default system categories + user custom categories)
const getCategories = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const [categories] = await pool.query(
      `SELECT id, user_id, name, icon, color, is_default
       FROM expense_categories
       WHERE user_id IS NULL OR user_id = ?
       ORDER BY is_default DESC, name ASC`,
      [userId]
    );

    return res.json({
      success: true,
      data: { categories }
    });
  } catch (error) {
    next(error);
  }
};

// 2. Create Custom Category
const createCategory = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { name, icon = 'category', color = '#2196F3' } = req.body;

    if (!name || name.trim() === '') {
      return res.status(400).json({ success: false, message: 'Category name is required.' });
    }

    const [result] = await pool.query(
      'INSERT INTO expense_categories (user_id, name, icon, color, is_default) VALUES (?, ?, ?, ?, FALSE)',
      [userId, name.trim(), icon, color]
    );

    return res.status(201).json({
      success: true,
      message: 'Category created successfully.',
      data: {
        category: {
          id: result.insertId,
          user_id: userId,
          name: name.trim(),
          icon,
          color,
          is_default: false
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// 3. Get Expenses (Grouped or filtered by date range / month)
const getExpenses = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { month, year, start_date, end_date } = req.query;

    let query = `
      SELECT e.id, e.user_id, e.category_id, e.amount, e.note, e.expense_date, e.created_at,
             c.name AS category_name, c.icon AS category_icon, c.color AS category_color
      FROM expenses e
      JOIN expense_categories c ON e.category_id = c.id
      WHERE e.user_id = ?
    `;
    const params = [userId];

    if (start_date && end_date) {
      query += ' AND e.expense_date BETWEEN ? AND ?';
      params.push(start_date, end_date);
    } else if (month && year) {
      query += ' AND MONTH(e.expense_date) = ? AND YEAR(e.expense_date) = ?';
      params.push(month, year);
    }

    query += ' ORDER BY e.expense_date DESC, e.id DESC';

    const [expenses] = await pool.query(query, params);

    // Group expenses by date (YYYY-MM-DD) for UI convenience
    const grouped = {};
    for (const item of expenses) {
      const dateKey = item.expense_date;
      if (!grouped[dateKey]) {
        grouped[dateKey] = {
          date: dateKey,
          total: 0,
          items: []
        };
      }
      grouped[dateKey].items.push(item);
      grouped[dateKey].total += Number(item.amount);
    }

    return res.json({
      success: true,
      data: {
        expenses,
        groupedByDate: Object.values(grouped)
      }
    });
  } catch (error) {
    next(error);
  }
};

// 4. Quick-Add / Create Expense
const createExpense = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { category_id, amount, note = '', expense_date } = req.body;

    if (!category_id || !amount) {
      return res.status(400).json({ success: false, message: 'Category and amount are required.' });
    }

    const parsedAmount = parseFloat(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({ success: false, message: 'Amount must be a positive number.' });
    }

    const date = expense_date ? formatDate(new Date(expense_date)) : formatDate(new Date());

    const [result] = await pool.query(
      'INSERT INTO expenses (user_id, category_id, amount, note, expense_date) VALUES (?, ?, ?, ?, ?)',
      [userId, category_id, parsedAmount, note ? note.trim() : null, date]
    );

    // Fetch created expense with category details
    const [created] = await pool.query(
      `SELECT e.id, e.user_id, e.category_id, e.amount, e.note, e.expense_date, e.created_at,
              c.name AS category_name, c.icon AS category_icon, c.color AS category_color
       FROM expenses e
       JOIN expense_categories c ON e.category_id = c.id
       WHERE e.id = ?`,
      [result.insertId]
    );

    return res.status(201).json({
      success: true,
      message: 'Expense added successfully.',
      data: { expense: created[0] }
    });
  } catch (error) {
    next(error);
  }
};

// 5. Update Expense
const updateExpense = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const expenseId = req.params.id;
    const { category_id, amount, note, expense_date } = req.body;

    const [existing] = await pool.query('SELECT id FROM expenses WHERE id = ? AND user_id = ?', [expenseId, userId]);
    if (existing.length === 0) {
      return res.status(404).json({ success: false, message: 'Expense not found.' });
    }

    const updates = [];
    const values = [];

    if (category_id !== undefined) { updates.push('category_id = ?'); values.push(category_id); }
    if (amount !== undefined) {
      const parsedAmount = parseFloat(amount);
      if (isNaN(parsedAmount) || parsedAmount <= 0) {
        return res.status(400).json({ success: false, message: 'Amount must be a positive number.' });
      }
      updates.push('amount = ?');
      values.push(parsedAmount);
    }
    if (note !== undefined) { updates.push('note = ?'); values.push(note ? note.trim() : null); }
    if (expense_date !== undefined) { updates.push('expense_date = ?'); values.push(formatDate(new Date(expense_date))); }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'No fields provided to update.' });
    }

    values.push(expenseId, userId);
    await pool.query(`UPDATE expenses SET ${updates.join(', ')} WHERE id = ? AND user_id = ?`, values);

    // Fetch updated expense
    const [updated] = await pool.query(
      `SELECT e.id, e.user_id, e.category_id, e.amount, e.note, e.expense_date, e.created_at,
              c.name AS category_name, c.icon AS category_icon, c.color AS category_color
       FROM expenses e
       JOIN expense_categories c ON e.category_id = c.id
       WHERE e.id = ?`,
      [expenseId]
    );

    return res.json({
      success: true,
      message: 'Expense updated successfully.',
      data: { expense: updated[0] }
    });
  } catch (error) {
    next(error);
  }
};

// 6. Delete Expense
const deleteExpense = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const expenseId = req.params.id;

    const [result] = await pool.query('DELETE FROM expenses WHERE id = ? AND user_id = ?', [expenseId, userId]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Expense not found.' });
    }

    return res.json({ success: true, message: 'Expense deleted successfully.' });
  } catch (error) {
    next(error);
  }
};

// 7. Summary Reports (Today, This Week, This Month totals, Category Breakdown, Daily Trend)
const getSummaryReports = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const todayStr = formatDate(new Date());

    // 1. Today's Total
    const [todayResult] = await pool.query(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE user_id = ? AND expense_date = ?',
      [userId, todayStr]
    );
    const todayTotal = parseFloat(todayResult[0].total);

    // 2. This Week's Total (Monday to Sunday)
    const [weekResult] = await pool.query(
      `SELECT COALESCE(SUM(amount), 0) AS total
       FROM expenses
       WHERE user_id = ? AND YEARWEEK(expense_date, 1) = YEARWEEK(CURDATE(), 1)`,
      [userId]
    );
    const weekTotal = parseFloat(weekResult[0].total);

    // 3. This Month's Total
    const [monthResult] = await pool.query(
      `SELECT COALESCE(SUM(amount), 0) AS total
       FROM expenses
       WHERE user_id = ? AND MONTH(expense_date) = MONTH(CURDATE()) AND YEAR(expense_date) = YEAR(CURDATE())`,
      [userId]
    );
    const monthTotal = parseFloat(monthResult[0].total);

    // 4. Category Breakdown (Current Month) for Pie Chart
    const [categoryBreakdown] = await pool.query(
      `SELECT c.id, c.name, c.color, c.icon, COALESCE(SUM(e.amount), 0) AS total_amount,
              COUNT(e.id) AS transaction_count
       FROM expenses e
       JOIN expense_categories c ON e.category_id = c.id
       WHERE e.user_id = ? AND MONTH(e.expense_date) = MONTH(CURDATE()) AND YEAR(e.expense_date) = YEAR(CURDATE())
       GROUP BY c.id, c.name, c.color, c.icon
       ORDER BY total_amount DESC`,
      [userId]
    );

    // 5. Daily Trend (Last 7 Days) for Bar Chart
    const [dailyTrend] = await pool.query(
      `SELECT expense_date, COALESCE(SUM(amount), 0) AS total
       FROM expenses
       WHERE user_id = ? AND expense_date >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
       GROUP BY expense_date
       ORDER BY expense_date ASC`,
      [userId]
    );

    return res.json({
      success: true,
      data: {
        summary: {
          today: todayTotal,
          this_week: weekTotal,
          this_month: monthTotal
        },
        category_breakdown: categoryBreakdown.map(c => ({
          ...c,
          total_amount: parseFloat(c.total_amount)
        })),
        daily_trend: dailyTrend.map(d => ({
          ...d,
          total: parseFloat(d.total)
        }))
      }
    });
  } catch (error) {
    next(error);
  }
};

// 8. Batch Offline Sync for Expenses
const batchSyncExpenses = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { expenses } = req.body; // Array of { category_id, amount, note, expense_date }

    if (!Array.isArray(expenses) || expenses.length === 0) {
      return res.status(400).json({ success: false, message: 'Expenses array is required.' });
    }

    const insertedIds = [];
    for (const exp of expenses) {
      const parsedAmount = parseFloat(exp.amount);
      const date = exp.expense_date ? formatDate(new Date(exp.expense_date)) : formatDate(new Date());

      const [result] = await pool.query(
        'INSERT INTO expenses (user_id, category_id, amount, note, expense_date) VALUES (?, ?, ?, ?, ?)',
        [userId, exp.category_id, parsedAmount, exp.note || null, date]
      );
      insertedIds.push(result.insertId);
    }

    return res.json({
      success: true,
      message: `Successfully synced ${insertedIds.length} expenses.`,
      data: { count: insertedIds.length }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getCategories,
  createCategory,
  getExpenses,
  createExpense,
  updateExpense,
  deleteExpense,
  getSummaryReports,
  batchSyncExpenses
};

