const mysql = require('mysql2/promise');
const dotenv = require('dotenv');

dotenv.config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'dailykit_db',
  port: Number(process.env.DB_PORT) || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  dateStrings: true, // Returns date strings (YYYY-MM-DD) instead of JS Date objects to avoid timezone offset issues
  charset: 'utf8mb4'
});

// Test connection on startup
(async () => {
  try {
    const connection = await pool.getConnection();
    console.log('✓ Successfully connected to MySQL database');
    connection.release();
  } catch (error) {
    console.error('✗ MySQL Database connection failed:', error.message);
  }
})();

module.exports = pool;

