const mysql = require('mysql2/promise');
const dotenv = require('dotenv');

dotenv.config();

const poolConfig = process.env.DATABASE_URL
  ? {
      uri: process.env.DATABASE_URL.split('?')[0],
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
      dateStrings: true,
      ssl: { rejectUnauthorized: false }
    }
  : {
      host: process.env.DB_HOST || '127.0.0.1',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'dailykit_db',
      port: Number(process.env.DB_PORT) || 3306,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
      dateStrings: true,
      charset: 'utf8mb4',
      ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined
    };

const pool = mysql.createPool(poolConfig);

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

