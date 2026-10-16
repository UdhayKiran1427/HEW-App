const pool = require('../config/db');

// 1. Get Items (with fast search across name, location, and tags)
const getItems = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { q, tag } = req.query;

    let query = `
      SELECT id, user_id, name, current_location, photo_url, tags, in_use_by, created_at, updated_at
      FROM items
      WHERE user_id = ?
    `;
    const params = [userId];

    if (q && q.trim() !== '') {
      const searchTerm = `%${q.trim()}%`;
      query += ` AND (name LIKE ? OR current_location LIKE ? OR tags LIKE ?)`;
      params.push(searchTerm, searchTerm, searchTerm);
    }

    if (tag && tag.trim() !== '') {
      query += ` AND tags LIKE ?`;
      params.push(`%${tag.trim()}%`);
    }

    query += ' ORDER BY updated_at DESC, id DESC';

    const [items] = await pool.query(query, params);

    return res.json({
      success: true,
      data: {
        total: items.length,
        items
      }
    });
  } catch (error) {
    next(error);
  }
};

// 2. Get Single Item with Location History
const getItemById = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const itemId = req.params.id;

    const [items] = await pool.query('SELECT * FROM items WHERE id = ? AND user_id = ?', [itemId, userId]);
    if (items.length === 0) {
      return res.status(404).json({ success: false, message: 'Item not found.' });
    }

    const item = items[0];

    // Fetch location history
    const [history] = await pool.query(
      'SELECT id, previous_location, new_location, notes, changed_at FROM item_location_history WHERE item_id = ? ORDER BY changed_at DESC',
      [itemId]
    );

    return res.json({
      success: true,
      data: {
        item: {
          ...item,
          history
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// 3. Create Item
const createItem = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { name, current_location, photo_url = null, tags = null, in_use_by = null } = req.body;

    if (!name || name.trim() === '') {
      return res.status(400).json({ success: false, message: 'Item name is required.' });
    }
    if (!current_location || current_location.trim() === '') {
      return res.status(400).json({ success: false, message: 'Current location is required.' });
    }

    const [result] = await pool.query(
      `INSERT INTO items (user_id, name, current_location, photo_url, tags, in_use_by)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [userId, name.trim(), current_location.trim(), photo_url, tags ? tags.trim() : null, in_use_by ? in_use_by.trim() : null]
    );

    // Initial history log entry
    await pool.query(
      `INSERT INTO item_location_history (item_id, previous_location, new_location, notes)
       VALUES (?, ?, ?, ?)`,
      [result.insertId, 'Initial creation', current_location.trim(), 'Item first registered in DailyKit']
    );

    const [created] = await pool.query('SELECT * FROM items WHERE id = ?', [result.insertId]);

    return res.status(201).json({
      success: true,
      message: 'Item saved successfully.',
      data: { item: created[0] }
    });
  } catch (error) {
    next(error);
  }
};

// 4. Update Item General Details (Name, Photo, Tags, In Use By)
const updateItem = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const itemId = req.params.id;
    const { name, photo_url, tags, in_use_by } = req.body;

    const [existing] = await pool.query('SELECT id FROM items WHERE id = ? AND user_id = ?', [itemId, userId]);
    if (existing.length === 0) {
      return res.status(404).json({ success: false, message: 'Item not found.' });
    }

    const updates = [];
    const values = [];

    if (name !== undefined) { updates.push('name = ?'); values.push(name.trim()); }
    if (photo_url !== undefined) { updates.push('photo_url = ?'); values.push(photo_url); }
    if (tags !== undefined) { updates.push('tags = ?'); values.push(tags ? tags.trim() : null); }
    if (in_use_by !== undefined) { updates.push('in_use_by = ?'); values.push(in_use_by ? in_use_by.trim() : null); }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'No fields provided to update.' });
    }

    values.push(itemId, userId);
    await pool.query(`UPDATE items SET ${updates.join(', ')} WHERE id = ? AND user_id = ?`, values);

    const [updated] = await pool.query('SELECT * FROM items WHERE id = ?', [itemId]);

    return res.json({
      success: true,
      message: 'Item updated successfully.',
      data: { item: updated[0] }
    });
  } catch (error) {
    next(error);
  }
};

// 5. Mark Item as "Moved" (Updates current location and records in history)
const moveItem = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const itemId = req.params.id;
    const { new_location, notes = '' } = req.body;

    if (!new_location || new_location.trim() === '') {
      return res.status(400).json({ success: false, message: 'New location is required.' });
    }

    // Verify item
    const [items] = await pool.query('SELECT * FROM items WHERE id = ? AND user_id = ?', [itemId, userId]);
    if (items.length === 0) {
      return res.status(404).json({ success: false, message: 'Item not found.' });
    }

    const item = items[0];
    const previousLocation = item.current_location;

    // Update item location
    await pool.query('UPDATE items SET current_location = ? WHERE id = ?', [new_location.trim(), itemId]);

    // Record into history
    await pool.query(
      `INSERT INTO item_location_history (item_id, previous_location, new_location, notes)
       VALUES (?, ?, ?, ?)`,
      [itemId, previousLocation, new_location.trim(), notes ? notes.trim() : null]
    );

    const [updated] = await pool.query('SELECT * FROM items WHERE id = ?', [itemId]);

    return res.json({
      success: true,
      message: 'Item location updated and recorded in history.',
      data: {
        item: updated[0],
        previous_location: previousLocation,
        new_location: new_location.trim()
      }
    });
  } catch (error) {
    next(error);
  }
};

// 6. Delete Item
const deleteItem = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const itemId = req.params.id;

    const [result] = await pool.query('DELETE FROM items WHERE id = ? AND user_id = ?', [itemId, userId]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Item not found.' });
    }

    return res.json({ success: true, message: 'Item deleted successfully.' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getItems,
  getItemById,
  createItem,
  updateItem,
  moveItem,
  deleteItem
};

