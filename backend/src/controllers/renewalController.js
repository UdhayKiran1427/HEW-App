const pool = require('../config/db');

// Helper to format Date to YYYY-MM-DD
const formatDate = (d) => {
  if (!d) return null;
  const date = new Date(d);
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

// 1. Get all renewals for the logged-in user
const getRenewals = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { category, status } = req.query;

    let query = `
      SELECT id, user_id, title, category, purchase_date, expiry_date, amount, notes,
             remind_before_days, is_renewed, created_at, updated_at,
             DATEDIFF(expiry_date, CURDATE()) AS days_remaining
      FROM renewals_warranties
      WHERE user_id = ?
    `;
    const params = [userId];

    if (category && category.trim() !== '') {
      query += ' AND category = ?';
      params.push(category.trim());
    }

    if (status === 'expiring_soon') {
      // Expiring in next 5 days
      query += ' AND DATEDIFF(expiry_date, CURDATE()) BETWEEN 0 AND 5 AND is_renewed = FALSE';
    } else if (status === 'expired') {
      query += ' AND expiry_date < CURDATE() AND is_renewed = FALSE';
    } else if (status === 'active') {
      query += ' AND expiry_date >= CURDATE() AND is_renewed = FALSE';
    }

    query += ' ORDER BY expiry_date ASC, id ASC';

    const [renewals] = await pool.query(query, params);

    return res.json({
      success: true,
      data: {
        total: renewals.length,
        renewals: renewals.map(r => ({
          ...r,
          amount: r.amount ? parseFloat(r.amount) : null,
          days_remaining: Number(r.days_remaining),
          status: Number(r.days_remaining) < 0
              ? 'expired'
              : (Number(r.days_remaining) <= 5 ? 'expiring_soon' : 'active')
        }))
      }
    });
  } catch (error) {
    next(error);
  }
};

// 2. Create new Renewal / Warranty entry
const createRenewal = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const {
      title,
      category = 'Subscription',
      purchase_date,
      expiry_date,
      amount,
      notes,
      remind_before_days = '5,3,1'
    } = req.body;

    if (!title || !expiry_date) {
      return res.status(400).json({
        success: false,
        message: 'Title and Expiry/Renewal Date are required.'
      });
    }

    const pDate = purchase_date ? formatDate(purchase_date) : null;
    const eDate = formatDate(expiry_date);
    const parsedAmount = amount ? parseFloat(amount) : null;

    const [result] = await pool.query(
      `INSERT INTO renewals_warranties 
       (user_id, title, category, purchase_date, expiry_date, amount, notes, remind_before_days)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [userId, title.trim(), category, pDate, eDate, parsedAmount, notes ? notes.trim() : null, remind_before_days]
    );

    const [created] = await pool.query(
      `SELECT id, user_id, title, category, purchase_date, expiry_date, amount, notes,
              remind_before_days, is_renewed, created_at,
              DATEDIFF(expiry_date, CURDATE()) AS days_remaining
       FROM renewals_warranties WHERE id = ?`,
      [result.insertId]
    );

    return res.status(201).json({
      success: true,
      message: 'Renewal reminder added successfully.',
      data: {
        renewal: {
          ...created[0],
          amount: created[0].amount ? parseFloat(created[0].amount) : null,
          days_remaining: Number(created[0].days_remaining)
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// 3. Update Renewal
const updateRenewal = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const id = req.params.id;
    const { title, category, purchase_date, expiry_date, amount, notes, remind_before_days, is_renewed } = req.body;

    const [existing] = await pool.query('SELECT id FROM renewals_warranties WHERE id = ? AND user_id = ?', [id, userId]);
    if (existing.length === 0) {
      return res.status(404).json({ success: false, message: 'Item not found.' });
    }

    const updates = [];
    const values = [];

    if (title !== undefined) { updates.push('title = ?'); values.push(title.trim()); }
    if (category !== undefined) { updates.push('category = ?'); values.push(category); }
    if (purchase_date !== undefined) { updates.push('purchase_date = ?'); values.push(formatDate(purchase_date)); }
    if (expiry_date !== undefined) { updates.push('expiry_date = ?'); values.push(formatDate(expiry_date)); }
    if (amount !== undefined) { updates.push('amount = ?'); values.push(amount ? parseFloat(amount) : null); }
    if (notes !== undefined) { updates.push('notes = ?'); values.push(notes ? notes.trim() : null); }
    if (remind_before_days !== undefined) { updates.push('remind_before_days = ?'); values.push(remind_before_days); }
    if (is_renewed !== undefined) { updates.push('is_renewed = ?'); values.push(is_renewed); }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'No fields provided for update.' });
    }

    values.push(id, userId);
    await pool.query(`UPDATE renewals_warranties SET ${updates.join(', ')} WHERE id = ? AND user_id = ?`, values);

    const [updated] = await pool.query(
      `SELECT id, user_id, title, category, purchase_date, expiry_date, amount, notes,
              remind_before_days, is_renewed, created_at,
              DATEDIFF(expiry_date, CURDATE()) AS days_remaining
       FROM renewals_warranties WHERE id = ?`,
      [id]
    );

    return res.json({
      success: true,
      message: 'Updated successfully.',
      data: { renewal: updated[0] }
    });
  } catch (error) {
    next(error);
  }
};

// 4. Delete Renewal
const deleteRenewal = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const id = req.params.id;

    const [result] = await pool.query('DELETE FROM renewals_warranties WHERE id = ? AND user_id = ?', [id, userId]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Item not found.' });
    }

    return res.json({ success: true, message: 'Deleted successfully.' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getRenewals,
  createRenewal,
  updateRenewal,
  deleteRenewal
};

