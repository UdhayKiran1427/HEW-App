class ApiEndpoints {
  // Live 24/7 Cloud API URL hosted on Render
  static const String liveCloudUrl = 'https://hew-app.onrender.com/api';

  static String get baseUrl {
    return liveCloudUrl;
  }

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/profile';
  static const String updateCurrency = '/auth/currency';

  // Habits
  static const String habits = '/habits';
  static String habitDetails(int id) => '/habits/$id';
  static String habitCheckIn(int id) => '/habits/$id/check-in';
  static const String habitsSyncBatch = '/habits/sync/batch';

  // Expenses
  static const String expenses = '/expenses';
  static const String categories = '/expenses/categories';
  static const String expenseReports = '/expenses/reports/summary';
  static String expenseItem(int id) => '/expenses/$id';
  static const String expensesSyncBatch = '/expenses/sync/batch';

  // Where I Kept It (Items)
  static const String items = '/items';
  static String itemDetails(int id) => '/items/$id';
  static String moveItem(int id) => '/items/$id/move';

  // Renewals & Warranties (Recharges, Subscriptions, Warranties)
  static const String renewals = '/renewals';
  static String renewalItem(int id) => '/renewals/$id';
}

