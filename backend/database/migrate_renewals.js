const mysql = require('mysql2/promise');
const dotenv = require('dotenv');

dotenv.config({ path: './.env' });

const ddl = `
CREATE TABLE IF NOT EXISTS renewals_warranties (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  title VARCHAR(150) NOT NULL,
  category VARCHAR(50) NOT NULL DEFAULT 'Subscription',
  purchase_date DATE NULL,
  expiry_date DATE NOT NULL,
  amount DECIMAL(10, 2) NULL,
  notes TEXT NULL,
  remind_before_days VARCHAR(50) DEFAULT '5,3,1',
  is_renewed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_renewals_user (user_id),
  INDEX idx_renewals_expiry (expiry_date)
);
`;

const sampleData = `
INSERT INTO renewals_warranties (user_id, title, category, purchase_date, expiry_date, amount, notes, remind_before_days) VALUES
(1, 'Airtel Mobile Recharge (3 Months)', 'Recharge', DATE_SUB(CURDATE(), INTERVAL 80 DAY), DATE_ADD(CURDATE(), INTERVAL 4 DAY), 666.00, 'Unlimited Calls + 1.5GB/day plan', '5,3,1'),
(1, 'Laptop Warranty (Asus Rog)', 'Warranty', DATE_SUB(CURDATE(), INTERVAL 350 DAY), DATE_ADD(CURDATE(), INTERVAL 15 DAY), 54999.00, 'Extended warranty covering hardware issues', '5,3,1'),
(1, 'Bike Insurance (HDFC Ergo)', 'Insurance', DATE_SUB(CURDATE(), INTERVAL 360 DAY), DATE_ADD(CURDATE(), INTERVAL 5 DAY), 1850.00, 'Comprehensive coverage policy #POL987654', '5,3,1')
ON DUPLICATE KEY UPDATE title=title;
`;

async function migrate() {
  try {
    const cleanUri = process.env.DATABASE_URL.split('?')[0];
    const aivenPool = mysql.createPool({ uri: cleanUri, ssl: { rejectUnauthorized: false } });
    await aivenPool.query(ddl);
    await aivenPool.query(sampleData);
    console.log('✓ renewals_warranties table & sample data created in Aiven Cloud MySQL!');
    aivenPool.end();
  } catch (e) {
    console.error('Aiven error:', e.message);
  }

  try {
    const localPool = mysql.createPool({
      host: process.env.DB_HOST || '127.0.0.1',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '1234',
      database: process.env.DB_NAME || 'dailykit_db',
      port: 3306
    });
    await localPool.query(ddl);
    await localPool.query(sampleData);
    console.log('✓ renewals_warranties table & sample data created in Local MySQL!');
    localPool.end();
  } catch (e) {
    console.error('Local error:', e.message);
  }
}

migrate();

