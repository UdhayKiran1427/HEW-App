import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../utils/local_streak_calculator.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'hew_local_storage.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 1. User Profile
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT DEFAULT 'User',
            email TEXT DEFAULT 'local@hew.app',
            currency TEXT DEFAULT 'INR'
          )
        ''');
        await db.rawInsert('''
          INSERT INTO user_profile (name, email, currency) VALUES ('User', 'local@hew.app', 'INR')
        ''');

        // 2. Habits
        await db.execute('''
          CREATE TABLE habits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            icon TEXT DEFAULT 'check_circle',
            color TEXT DEFAULT '#4CAF50',
            target_days_per_week INTEGER DEFAULT 7,
            reminder_time TEXT,
            is_archived INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // 3. Habit Logs
        await db.execute('''
          CREATE TABLE habit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            habit_id INTEGER NOT NULL,
            log_date TEXT NOT NULL,
            completed INTEGER DEFAULT 1,
            UNIQUE(habit_id, log_date),
            FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
          )
        ''');

        // 4. Expense Categories
        await db.execute('''
          CREATE TABLE expense_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            icon TEXT DEFAULT 'category',
            color TEXT DEFAULT '#2196F3',
            is_default INTEGER DEFAULT 0
          )
        ''');

        // Seed Default Categories
        final defaults = [
          {'name': 'Food', 'icon': 'restaurant', 'color': '#FF5722', 'is_default': 1},
          {'name': 'Travel', 'icon': 'directions_car', 'color': '#2196F3', 'is_default': 1},
          {'name': 'Bills', 'icon': 'receipt_long', 'color': '#9C27B0', 'is_default': 1},
          {'name': 'Shopping', 'icon': 'shopping_bag', 'color': '#E91E63', 'is_default': 1},
          {'name': 'Health', 'icon': 'favorite', 'color': '#4CAF50', 'is_default': 1},
          {'name': 'Other', 'icon': 'more_horiz', 'color': '#607D8B', 'is_default': 1},
        ];
        for (final cat in defaults) {
          await db.insert('expense_categories', cat);
        }

        // 5. Expenses
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            note TEXT,
            expense_date TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (category_id) REFERENCES expense_categories(id)
          )
        ''');

        // 6. Items (Where I Kept It)
        await db.execute('''
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            current_location TEXT NOT NULL,
            photo_url TEXT,
            tags TEXT,
            in_use_by TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // 7. Item Location History
        await db.execute('''
          CREATE TABLE item_location_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id INTEGER NOT NULL,
            previous_location TEXT NOT NULL,
            new_location TEXT NOT NULL,
            moved_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
          )
        ''');

        // 8. Renewals & Warranties
        await db.execute('''
          CREATE TABLE renewals_warranties (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            category TEXT DEFAULT 'Subscription',
            purchase_date TEXT,
            expiry_date TEXT NOT NULL,
            amount REAL,
            notes TEXT,
            remind_before_days TEXT DEFAULT '5,3,1',
            is_renewed INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // USER PROFILE
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getUserProfile() async {
    final db = await database;
    final rows = await db.query('user_profile', limit: 1);
    if (rows.isNotEmpty) {
      return Map<String, dynamic>.from(rows.first);
    }
    return {'id': 1, 'name': 'User', 'email': 'local@hew.app', 'currency': 'INR'};
  }

  Future<void> updateUserProfile({String? name, String? currency}) async {
    final db = await database;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (currency != null) updates['currency'] = currency;
    if (updates.isNotEmpty) {
      await db.update('user_profile', updates, where: 'id = 1');
    }
  }

  Future<String> getDatabaseSize() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = p.join(databasesPath, 'hew_local_storage.db');
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.length();
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
    } catch (_) {}
    return '0 KB';
  }

  // ---------------------------------------------------------------------------
  // HABITS
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getHabits() async {
    final db = await database;
    final habits = await db.query(
      'habits',
      where: 'is_archived = 0',
      orderBy: 'id ASC',
    );

    final todayStr = _today();
    final List<Map<String, dynamic>> result = [];

    for (final h in habits) {
      final hMap = Map<String, dynamic>.from(h);
      final habitId = h['id'] as int;

      final logs = await db.query(
        'habit_logs',
        columns: ['log_date'],
        where: 'habit_id = ? AND completed = 1',
        whereArgs: [habitId],
        orderBy: 'log_date ASC',
      );

      final dates = logs.map((l) => l['log_date'] as String).toList();
      final streak = LocalStreakCalculator.calculate(dates);

      hMap['is_completed_today'] = dates.contains(todayStr);
      hMap['current_streak'] = streak.currentStreak;
      hMap['longest_streak'] = streak.longestStreak;
      hMap['total_completions'] = dates.length;
      hMap['target_days_per_week'] = h['target_days_per_week'] ?? 7;

      result.add(hMap);
    }
    return result;
  }

  Future<Map<String, dynamic>?> getHabitDetails(int habitId) async {
    final db = await database;
    final rows = await db.query('habits', where: 'id = ?', limit: 1);
    if (rows.isEmpty) return null;

    final hMap = Map<String, dynamic>.from(rows.first);
    final logs = await db.query(
      'habit_logs',
      columns: ['log_date'],
      where: 'habit_id = ? AND completed = 1',
      orderBy: 'log_date ASC',
    );

    final dates = logs.map((l) => l['log_date'] as String).toList();
    final streak = LocalStreakCalculator.calculate(dates);

    hMap['logs'] = dates;
    hMap['current_streak'] = streak.currentStreak;
    hMap['longest_streak'] = streak.longestStreak;
    hMap['total_completions'] = dates.length;
    hMap['is_completed_today'] = dates.contains(_today());
    hMap['target_days_per_week'] = hMap['target_days_per_week'] ?? 7;

    return hMap;
  }

  Future<Map<String, dynamic>> createHabit({
    required String name,
    String icon = 'check_circle',
    String color = '#4CAF50',
    int targetDaysPerWeek = 7,
    String? reminderTime,
  }) async {
    final db = await database;
    final id = await db.insert('habits', {
      'name': name.trim(),
      'icon': icon,
      'color': color,
      'target_days_per_week': targetDaysPerWeek,
      'reminder_time': reminderTime,
      'is_archived': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    return {
      'id': id,
      'name': name.trim(),
      'icon': icon,
      'color': color,
      'target_days_per_week': targetDaysPerWeek,
      'reminder_time': reminderTime,
      'is_completed_today': false,
      'current_streak': 0,
      'longest_streak': 0,
      'total_completions': 0,
    };
  }

  Future<void> updateHabit({
    required int habitId,
    required String name,
    required String icon,
    required String color,
    required int targetDaysPerWeek,
    String? reminderTime,
  }) async {
    final db = await database;
    await db.update(
      'habits',
      {
        'name': name.trim(),
        'icon': icon,
        'color': color,
        'target_days_per_week': targetDaysPerWeek,
        'reminder_time': reminderTime,
      },
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<void> deleteHabit(int habitId) async {
    final db = await database;
    await db.delete('habit_logs', where: 'habit_id = ?', whereArgs: [habitId]);
    await db.delete('habits', where: 'id = ?', whereArgs: [habitId]);
  }

  Future<bool> toggleHabitCheckIn(int habitId, {String? date}) async {
    final db = await database;
    final targetDate = date ?? _today();

    final existing = await db.query(
      'habit_logs',
      where: 'habit_id = ? AND log_date = ?',
      whereArgs: [habitId, targetDate],
    );

    if (existing.isNotEmpty) {
      await db.delete(
        'habit_logs',
        where: 'habit_id = ? AND log_date = ?',
        whereArgs: [habitId, targetDate],
      );
      return false; // unchecked
    } else {
      await db.insert('habit_logs', {
        'habit_id': habitId,
        'log_date': targetDate,
        'completed': 1,
      });
      return true; // checked
    }
  }

  // ---------------------------------------------------------------------------
  // EXPENSES
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    final db = await database;
    final rows = await db.query(
      'expense_categories',
      orderBy: 'is_default DESC, name ASC',
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<Map<String, dynamic>> createExpenseCategory({
    required String name,
    String icon = 'category',
    String color = '#2196F3',
  }) async {
    final db = await database;
    final id = await db.insert('expense_categories', {
      'name': name.trim(),
      'icon': icon,
      'color': color,
      'is_default': 0,
    });
    return {
      'id': id,
      'name': name.trim(),
      'icon': icon,
      'color': color,
      'is_default': 0,
    };
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT e.id, e.category_id, e.amount, e.note, e.expense_date, e.created_at,
             c.name as category_name, c.icon as category_icon, c.color as category_color
      FROM expenses e
      LEFT JOIN expense_categories c ON e.category_id = c.id
      ORDER BY e.expense_date DESC, e.id DESC
    ''');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<Map<String, dynamic>> createExpense({
    required int categoryId,
    required double amount,
    String? note,
    required String expenseDate,
  }) async {
    final db = await database;
    final id = await db.insert('expenses', {
      'category_id': categoryId,
      'amount': amount,
      'note': note,
      'expense_date': expenseDate,
      'created_at': DateTime.now().toIso8601String(),
    });

    final catRows = await db.query('expense_categories', where: 'id = ?', whereArgs: [categoryId]);
    final cat = catRows.isNotEmpty ? catRows.first : {};

    return {
      'id': id,
      'category_id': categoryId,
      'category_name': cat['name'] ?? 'Expense',
      'category_icon': cat['icon'] ?? 'category',
      'category_color': cat['color'] ?? '#2196F3',
      'amount': amount,
      'note': note,
      'expense_date': expenseDate,
    };
  }

  Future<Map<String, dynamic>> updateExpense({
    required int expenseId,
    required int categoryId,
    required double amount,
    String? note,
    required String expenseDate,
  }) async {
    final db = await database;
    await db.update(
      'expenses',
      {
        'category_id': categoryId,
        'amount': amount,
        'note': note,
        'expense_date': expenseDate,
      },
      where: 'id = ?',
      whereArgs: [expenseId],
    );

    final catRows = await db.query('expense_categories', where: 'id = ?', whereArgs: [categoryId]);
    final cat = catRows.isNotEmpty ? catRows.first : {};

    return {
      'id': expenseId,
      'category_id': categoryId,
      'category_name': cat['name'] ?? 'Expense',
      'category_icon': cat['icon'] ?? 'category',
      'category_color': cat['color'] ?? '#2196F3',
      'amount': amount,
      'note': note,
      'expense_date': expenseDate,
    };
  }

  Future<void> deleteExpense(int expenseId) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
  }

  Future<Map<String, dynamic>> getExpenseSummaryReport({int days = 30}) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));
    final startStr = _formatDate(startDate);

    // Total Spent
    final totalRows = await db.rawQuery('''
      SELECT SUM(amount) as total FROM expenses WHERE expense_date >= ?
    ''', [startStr]);
    final total = totalRows.first['total'] != null ? (totalRows.first['total'] as num).toDouble() : 0.0;

    // By Category
    final catRows = await db.rawQuery('''
      SELECT c.name, c.color, c.icon, SUM(e.amount) as category_total
      FROM expenses e
      JOIN expense_categories c ON e.category_id = c.id
      WHERE e.expense_date >= ?
      GROUP BY c.id
      ORDER BY category_total DESC
    ''', [startStr]);

    // Daily Spending
    final dailyRows = await db.rawQuery('''
      SELECT expense_date, SUM(amount) as daily_total
      FROM expenses
      WHERE expense_date >= ?
      GROUP BY expense_date
      ORDER BY expense_date ASC
    ''', [startStr]);

    return {
      'total_spent': total,
      'categories': catRows.map((r) {
        final catTot = (r['category_total'] as num).toDouble();
        return {
          'name': r['name'],
          'color': r['color'],
          'icon': r['icon'],
          'total': catTot,
          'percentage': total > 0 ? (catTot / total * 100) : 0.0,
        };
      }).toList(),
      'daily': dailyRows.map((r) => {
        'date': r['expense_date'],
        'total': (r['daily_total'] as num).toDouble(),
      }).toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // ITEMS (Where I Kept It)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getItems({String? query, String? tag}) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (query != null && query.trim().isNotEmpty) {
      where += ' AND (name LIKE ? OR current_location LIKE ? OR tags LIKE ?)';
      final q = '%${query.trim()}%';
      whereArgs.addAll([q, q, q]);
    }
    if (tag != null && tag != 'all') {
      where += ' AND tags LIKE ?';
      whereArgs.add('%$tag%');
    }

    final rows = await db.query(
      'items',
      where: whereArgs.isNotEmpty ? where : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'updated_at DESC, id DESC',
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<Map<String, dynamic>?> getItemDetails(int itemId) async {
    final db = await database;
    final itemRows = await db.query('items', where: 'id = ?', whereArgs: [itemId], limit: 1);
    if (itemRows.isEmpty) return null;

    final itemMap = Map<String, dynamic>.from(itemRows.first);

    final historyRows = await db.query(
      'item_location_history',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'moved_at DESC, id DESC',
    );

    itemMap['location_history'] = historyRows.map((h) => Map<String, dynamic>.from(h)).toList();
    return itemMap;
  }

  Future<Map<String, dynamic>> createItem({
    required String name,
    required String currentLocation,
    String? photoUrl,
    String? tags,
    String? inUseBy,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('items', {
      'name': name.trim(),
      'current_location': currentLocation.trim(),
      'photo_url': photoUrl,
      'tags': tags,
      'in_use_by': inUseBy,
      'created_at': now,
      'updated_at': now,
    });

    return {
      'id': id,
      'name': name.trim(),
      'current_location': currentLocation.trim(),
      'photo_url': photoUrl,
      'tags': tags,
      'in_use_by': inUseBy,
      'created_at': now,
      'updated_at': now,
      'location_history': [],
    };
  }

  Future<Map<String, dynamic>> updateItemLocation({
    required int itemId,
    required String newLocation,
  }) async {
    final db = await database;
    final item = await getItemDetails(itemId);
    final previousLocation = item?['current_location'] ?? 'Unknown';
    final now = DateTime.now().toIso8601String();

    // Log history
    await db.insert('item_location_history', {
      'item_id': itemId,
      'previous_location': previousLocation,
      'new_location': newLocation.trim(),
      'moved_at': now,
    });

    // Update item
    await db.update(
      'items',
      {
        'current_location': newLocation.trim(),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );

    return (await getItemDetails(itemId))!;
  }

  Future<Map<String, dynamic>> updateItem({
    required int itemId,
    required String name,
    required String currentLocation,
    String? tags,
    String? inUseBy,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'items',
      {
        'name': name.trim(),
        'current_location': currentLocation.trim(),
        'tags': tags,
        'in_use_by': inUseBy,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );

    return (await getItemDetails(itemId))!;
  }

  Future<void> deleteItem(int itemId) async {
    final db = await database;
    await db.delete('item_location_history', where: 'item_id = ?', whereArgs: [itemId]);
    await db.delete('items', where: 'id = ?', whereArgs: [itemId]);
  }

  // ---------------------------------------------------------------------------
  // RENEWALS & WARRANTIES
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getRenewals({String? category, String? status}) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (category != null && category != 'All') {
      where += ' AND category = ?';
      whereArgs.add(category);
    }

    final rows = await db.query(
      'renewals_warranties',
      where: whereArgs.isNotEmpty ? where : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'expiry_date ASC, id ASC',
    );

    final today = DateTime.now();
    final todayZero = DateTime(today.year, today.month, today.day);

    final enriched = rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      final expiry = DateTime.tryParse(map['expiry_date'] as String? ?? '');
      int daysRemaining = 0;
      String itemStatus = 'active';

      if (expiry != null) {
        final expZero = DateTime(expiry.year, expiry.month, expiry.day);
        daysRemaining = expZero.difference(todayZero).inDays;
      }

      if (daysRemaining < 0) {
        itemStatus = 'expired';
      } else if (daysRemaining <= 5) {
        itemStatus = 'expiring_soon';
      } else {
        itemStatus = 'active';
      }

      map['days_remaining'] = daysRemaining;
      map['status'] = itemStatus;
      return map;
    }).toList();

    if (status != null && status != 'All' && status.isNotEmpty) {
      final s = status.toLowerCase().replaceAll(' ', '_');
      return enriched.where((item) => item['status'] == s).toList();
    }

    return enriched;
  }

  Future<Map<String, dynamic>> createRenewal({
    required String title,
    required String category,
    String? purchaseDate,
    required String expiryDate,
    double? amount,
    String? notes,
    String remindBeforeDays = '5,3,1',
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('renewals_warranties', {
      'title': title.trim(),
      'category': category,
      'purchase_date': purchaseDate,
      'expiry_date': expiryDate,
      'amount': amount,
      'notes': notes,
      'remind_before_days': remindBeforeDays,
      'is_renewed': 0,
      'created_at': now,
      'updated_at': now,
    });

    final list = await getRenewals();
    return list.firstWhere((r) => r['id'] == id);
  }

  Future<Map<String, dynamic>> updateRenewal({
    required int id,
    required String title,
    required String category,
    String? purchaseDate,
    required String expiryDate,
    double? amount,
    String? notes,
    String? remindBeforeDays,
    bool? isRenewed,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final updates = <String, dynamic>{
      'title': title.trim(),
      'category': category,
      'purchase_date': purchaseDate,
      'expiry_date': expiryDate,
      'amount': amount,
      'notes': notes,
      'updated_at': now,
    };
    if (remindBeforeDays != null) updates['remind_before_days'] = remindBeforeDays;
    if (isRenewed != null) updates['is_renewed'] = isRenewed ? 1 : 0;

    await db.update('renewals_warranties', updates, where: 'id = ?', whereArgs: [id]);

    final list = await getRenewals();
    return list.firstWhere((r) => r['id'] == id);
  }

  Future<void> deleteRenewal(int id) async {
    final db = await database;
    await db.delete('renewals_warranties', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  static String _today() {
    return _formatDate(DateTime.now());
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // ---------------------------------------------------------------------------
  // BACKUP & RESTORE
  // ---------------------------------------------------------------------------
  Future<String> getDatabaseFilePath() async {
    final databasesPath = await getDatabasesPath();
    return p.join(databasesPath, 'hew_local_storage.db');
  }

  Future<Map<String, dynamic>> exportFullBackup() async {
    final db = await database;
    final habits = await db.query('habits');
    final habitLogs = await db.query('habit_logs');
    final expenseCategories = await db.query('expense_categories');
    final expenses = await db.query('expenses');
    final items = await db.query('items');
    final itemLocationHistory = await db.query('item_location_history');
    final renewals = await db.query('renewals_warranties');
    final userProfile = await db.query('user_profile');

    return {
      'app': 'HEW',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'summary': {
        'habits_count': habits.length,
        'habit_logs_count': habitLogs.length,
        'expenses_count': expenses.length,
        'items_count': items.length,
        'renewals_count': renewals.length,
      },
      'user_profile': userProfile,
      'habits': habits,
      'habit_logs': habitLogs,
      'expense_categories': expenseCategories,
      'expenses': expenses,
      'items': items,
      'item_location_history': itemLocationHistory,
      'renewals_warranties': renewals,
    };
  }

  Future<void> importFullBackup(Map<String, dynamic> backup) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. User Profile
      if (backup['user_profile'] is List && (backup['user_profile'] as List).isNotEmpty) {
        await txn.delete('user_profile');
        for (final row in (backup['user_profile'] as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          await txn.insert('user_profile', map);
        }
      }

      // 2. Habits & Logs
      if (backup['habits'] is List) {
        await txn.delete('habit_logs');
        await txn.delete('habits');
        for (final row in (backup['habits'] as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          await txn.insert('habits', map);
        }
        if (backup['habit_logs'] is List) {
          for (final row in (backup['habit_logs'] as List)) {
            final map = Map<String, dynamic>.from(row as Map);
            await txn.insert('habit_logs', map);
          }
        }
      }

      // 3. Expense Categories & Expenses
      if (backup['expense_categories'] is List && (backup['expense_categories'] as List).isNotEmpty) {
        await txn.delete('expenses');
        await txn.delete('expense_categories');
        for (final row in (backup['expense_categories'] as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          await txn.insert('expense_categories', map);
        }
      }
      if (backup['expenses'] is List) {
        await txn.delete('expenses');
        for (final row in (backup['expenses'] as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          await txn.insert('expenses', map);
        }
      }

      // 4. Items & History
      if (backup['items'] is List) {
        await txn.delete('item_location_history');
        await txn.delete('items');
        for (final row in (backup['items'] as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          await txn.insert('items', map);
        }
        if (backup['item_location_history'] is List) {
          for (final row in (backup['item_location_history'] as List)) {
            final map = Map<String, dynamic>.from(row as Map);
            await txn.insert('item_location_history', map);
          }
        }
      }

      // 5. Renewals & Warranties
      if (backup['renewals_warranties'] is List) {
        await txn.delete('renewals_warranties');
        for (final row in (backup['renewals_warranties'] as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          await txn.insert('renewals_warranties', map);
        }
      }
    });
  }
}

