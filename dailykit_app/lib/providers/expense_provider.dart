import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/local_database_service.dart';
import '../models/expense_model.dart';

class ExpenseProvider extends ChangeNotifier {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  static const String _lastCategoryKey = 'last_used_category_id';

  List<ExpenseModel> _expenses = [];
  List<ExpenseCategory> _categories = [];
  ExpenseSummaryReport? _summaryReport;
  int? _lastUsedCategoryId;

  bool _isLoading = false;
  String? _errorMessage;

  List<ExpenseModel> get expenses => _expenses;
  List<ExpenseCategory> get categories => _categories;
  ExpenseSummaryReport? get summaryReport => _summaryReport;
  int? get lastUsedCategoryId => _lastUsedCategoryId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ExpenseProvider() {
    _loadLastUsedCategory();
    fetchCategories();
  }

  Future<void> _loadLastUsedCategory() async {
    final prefs = await SharedPreferences.getInstance();
    _lastUsedCategoryId = prefs.getInt(_lastCategoryKey);
    notifyListeners();
  }

  // 1. Fetch Categories from SQLite
  Future<void> fetchCategories() async {
    try {
      final list = await _localDb.getExpenseCategories();
      _categories = list.map((c) => ExpenseCategory.fromJson(c)).toList();
      notifyListeners();
    } catch (_) {}
  }

  // 2. Fetch Expenses List from SQLite
  Future<void> fetchExpenses({bool refresh = false}) async {
    if (_expenses.isEmpty || refresh) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final list = await _localDb.getExpenses();
      _expenses = list.map((e) => ExpenseModel.fromJson(e)).toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. Quick-Add Expense in SQLite (< 1s flow, instant local storage)
  Future<bool> addExpense({
    required int categoryId,
    required double amount,
    String? note,
    required String expenseDate,
  }) async {
    _lastUsedCategoryId = categoryId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCategoryKey, categoryId);

    try {
      final createdMap = await _localDb.createExpense(
        categoryId: categoryId,
        amount: amount,
        note: note,
        expenseDate: expenseDate,
      );

      final created = ExpenseModel.fromJson(createdMap);
      _expenses.insert(0, created);
      // Sort by date descending
      _expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // 4. Update Expense in SQLite
  Future<bool> updateExpense({
    required int expenseId,
    required int categoryId,
    required double amount,
    String? note,
    required String expenseDate,
  }) async {
    try {
      final updatedMap = await _localDb.updateExpense(
        expenseId: expenseId,
        categoryId: categoryId,
        amount: amount,
        note: note,
        expenseDate: expenseDate,
      );

      final updated = ExpenseModel.fromJson(updatedMap);
      final index = _expenses.indexWhere((e) => e.id == expenseId);
      if (index != -1) {
        _expenses[index] = updated;
        _expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // 5. Delete Expense in SQLite
  Future<bool> deleteExpense(ExpenseModel expense) async {
    final originalIndex = _expenses.indexOf(expense);
    _expenses.remove(expense);
    notifyListeners();

    try {
      await _localDb.deleteExpense(expense.id);
      return true;
    } catch (_) {
      if (originalIndex != -1) {
        _expenses.insert(originalIndex, expense);
        notifyListeners();
      }
      return false;
    }
  }

  // 6. Fetch Summary Reports for Charts from SQLite
  Future<void> fetchSummaryReports() async {
    try {
      final data = await _localDb.getExpenseSummaryReport();
      _summaryReport = ExpenseSummaryReport.fromJson(data);
      notifyListeners();
    } catch (_) {}
  }

  // 7. Create Custom Category in SQLite
  Future<bool> createCategory({required String name, required String icon, required String color}) async {
    try {
      final newCatMap = await _localDb.createExpenseCategory(
        name: name,
        icon: icon,
        color: color,
      );
      final newCategory = ExpenseCategory.fromJson(newCatMap);
      _categories.add(newCategory);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
