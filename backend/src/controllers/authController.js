const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

// Generate JWT Helper
const generateToken = (userId, email) => {
  return jwt.sign(
    { id: userId, email },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '30d' }
  );
};

// 1. User Registration
const register = async (req, res, next) => {
  try {
    const { name, email, password, currency = 'INR' } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Name, email, and password are required fields.'
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters long.'
      });
    }

    // Check if email already registered
    const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [email.toLowerCase().trim()]);
    if (existing.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'An account with this email address already exists.'
      });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    // Insert user
    const [result] = await pool.query(
      'INSERT INTO users (name, email, password_hash, currency) VALUES (?, ?, ?, ?)',
      [name.trim(), email.toLowerCase().trim(), passwordHash, currency.toUpperCase()]
    );

    const userId = result.insertId;
    const token = generateToken(userId, email.toLowerCase().trim());

    return res.status(201).json({
      success: true,
      message: 'Account registered successfully.',
      data: {
        token,
        user: {
          id: userId,
          name: name.trim(),
          email: email.toLowerCase().trim(),
          currency: currency.toUpperCase()
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// 2. User Login
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide both email and password.'
      });
    }

    const [rows] = await pool.query(
      'SELECT id, name, email, password_hash, currency FROM users WHERE email = ?',
      [email.toLowerCase().trim()]
    );

    if (rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.'
      });
    }

    const user = rows[0];
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.'
      });
    }

    const token = generateToken(user.id, user.email);

    return res.json({
      success: true,
      message: 'Logged in successfully.',
      data: {
        token,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          currency: user.currency
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// 3. Get User Profile
const getProfile = async (req, res, next) => {
  try {
    return res.json({
      success: true,
      data: {
        user: req.user
      }
    });
  } catch (error) {
    next(error);
  }
};

// 4. Update Currency Preference
const updateCurrency = async (req, res, next) => {
  try {
    const { currency } = req.body;
    if (!currency) {
      return res.status(400).json({ success: false, message: 'Currency code is required.' });
    }

    await pool.query('UPDATE users SET currency = ? WHERE id = ?', [currency.toUpperCase(), req.user.id]);

    return res.json({
      success: true,
      message: 'Currency preference updated.',
      data: { currency: currency.toUpperCase() }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
  getProfile,
  updateCurrency
};

