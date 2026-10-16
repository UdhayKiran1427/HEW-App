-- ==========================================================
-- DailyKit Seed Data Script
-- ==========================================================

USE dailykit_db;

-- 1. Insert Default System Expense Categories (user_id = NULL)
INSERT INTO expense_categories (user_id, name, icon, color, is_default) VALUES
  (NULL, 'Food', 'restaurant', '#FF5722', TRUE),
  (NULL, 'Travel', 'directions_car', '#2196F3', TRUE),
  (NULL, 'Bills', 'receipt_long', '#9C27B0', TRUE),
  (NULL, 'Shopping', 'shopping_bag', '#E91E63', TRUE),
  (NULL, 'Health', 'favorite', '#4CAF50', TRUE),
  (NULL, 'Other', 'more_horiz', '#607D8B', TRUE)
ON DUPLICATE KEY UPDATE name=name;

-- 2. Demo User (Password is 'password123' hashed with bcrypt: $2b$10$wT5gQz2fF8d6S7h7V0.QneX3Xp9Cq0Xz9W2T4m3Z1e2Y1g8Q8i2eK)
INSERT INTO users (id, name, email, password_hash, currency) VALUES
  (1, 'Demo User', 'demo@dailykit.com', '$2b$10$J01O94t21wF2vL1UeZq5A.h3w5j8PZ4.T8N7rZ.rTqjO5u6O7V6iW', 'INR')
ON DUPLICATE KEY UPDATE email=email;

-- 3. Demo Habits for User 1
INSERT INTO habits (id, user_id, name, icon, color, target_days_per_week, reminder_time) VALUES
  (1, 1, 'Morning Meditation', 'self_improvement', '#673AB7', 7, '06:30:00'),
  (2, 1, 'Read 20 Pages', 'menu_book', '#3F51B5', 5, '21:00:00'),
  (3, 1, 'Drink 3L Water', 'water_drop', '#00BCD4', 7, '09:00:00'),
  (4, 1, '30 Min Workout', 'fitness_center', '#FF9800', 4, '18:00:00')
ON DUPLICATE KEY UPDATE name=name;

-- 4. Demo Habit Logs for recent days
INSERT INTO habit_logs (habit_id, user_id, log_date, completed) VALUES
  (1, 1, CURDATE(), TRUE),
  (1, 1, DATE_SUB(CURDATE(), INTERVAL 1 DAY), TRUE),
  (1, 1, DATE_SUB(CURDATE(), INTERVAL 2 DAY), TRUE),
  (2, 1, CURDATE(), TRUE),
  (3, 1, CURDATE(), TRUE),
  (3, 1, DATE_SUB(CURDATE(), INTERVAL 1 DAY), TRUE)
ON DUPLICATE KEY UPDATE completed=completed;

-- 5. Demo Expenses for User 1
INSERT INTO expenses (user_id, category_id, amount, note, expense_date) VALUES
  (1, 1, 240.00, 'Lunch at cafeteria', CURDATE()),
  (1, 2, 85.00, 'Metro recharge', CURDATE()),
  (1, 4, 1299.00, 'New running shoes', DATE_SUB(CURDATE(), INTERVAL 2 DAY)),
  (1, 3, 750.00, 'Internet bill', DATE_SUB(CURDATE(), INTERVAL 4 DAY)),
  (1, 5, 350.00, 'Multivitamin supplements', DATE_SUB(CURDATE(), INTERVAL 6 DAY))
ON DUPLICATE KEY UPDATE amount=amount;

-- 6. Demo Items (Where I Kept It)
INSERT INTO items (id, user_id, name, current_location, photo_url, tags, in_use_by) VALUES
  (1, 1, 'Passport & Visa Docs', 'Blue file, second shelf of bedroom almirah', NULL, 'documents,travel,important', NULL),
  (2, 1, 'MacBook Charger', 'Work desk cable drawer, bottom pouch', NULL, 'electronics,work', NULL),
  (3, 1, 'Power Drill (Bosch)', 'Utility shelf in garage, toolbox box 3', NULL, 'tools,hardware', 'Rohan (Lent on Oct 10)'),
  (4, 1, 'Spare Car Keys', 'Entrance key cabinet, hook #4', NULL, 'keys,vehicle', NULL)
ON DUPLICATE KEY UPDATE name=name;

-- 7. Demo Location History
INSERT INTO item_location_history (item_id, previous_location, new_location, notes) VALUES
  (3, 'Store room shelf 1', 'Utility shelf in garage, toolbox box 3', 'Moved for easy access before lending to Rohan');

