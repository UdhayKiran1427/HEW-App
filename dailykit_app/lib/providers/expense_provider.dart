import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/offline_sync_queue.dart';
import '../models/expense_model.dart';

class ExpenseProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
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
  }

  Future<void> _loadLastUsedCategory() async {
    final prefs = await SharedPreferences.getInstance();
    _lastUsedCategoryId = prefs.getInt(_lastCategoryKey);
    notifyListeners();
  }

  // 1. Fetch Categories
  Future<void> fetchCategories() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.categories);
      if (response.data['success'] == true) {
        final List list = response.data['data']['categories'];
        _categories = list.map((c) => ExpenseCategory.fromJson(c)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  // 2. Fetch Expenses List
  Future<void> fetchExpenses({bool refresh = false}) async {
    if (_expenses.isEmpty || refresh) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final response = await _apiClient.dio.get(ApiEndpoints.expenses);
      if (response.data['success'] == true) {
        final List list = response.data['data']['expenses'];
        _expenses = list.map((e) => ExpenseModel.fromJson(e)).toList();
        _errorMessage = null;
      }
    } on DioException catch (e) {
      _errorMessage = e.message ?? 'Failed to load expenses.';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. Quick-Add Expense (< 5s flow)
  Future<bool> addExpense({
    required int categoryId,
    required double amount,
    String? note,
    required String expenseDate,
  }) async {
    // Remember last used category for <5s quick add next time
    _lastUsedCategoryId = categoryId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCategoryKey, categoryId);

    // Optimistic item creation
    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => ExpenseCategory(id: categoryId, name: 'Expense'),
    );

    final tempExpense = ExpenseModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: 0,
      categoryId: categoryId,
      categoryName: category.name,
      categoryIcon: category.icon,
      categoryColor: category.color,
      amount: amount,
      note: note,
      expenseDate: expenseDate,
    );

    _expenses.insert(0, tempExpense);
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.expenses,
        data: {
          'category_id': categoryId,
          'amount': amount,
          'note': note,
          'expense_date': expenseDate,
        },
      );

      if (response.data['success'] == true) {
        final created = ExpenseModel.fromJson(response.data['data']['expense']);
        final idx = _expenses.indexWhere((e) => e.id == tempExpense.id);
        if (idx != -1) {
          _expenses[idx] = created;
        }
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Offline fallback: queue locally
      await OfflineSyncQueue.queueExpense(
        categoryId: categoryId,
        amount: amount,
        note: note ?? '',
        date: expenseDate,
      );
    }
    return true;
  }

  // 4. Update Expense
  Future<bool> updateExpense({
    required int expenseId,
    required int categoryId,
    required double amount,
    String? note,
    required String expenseDate,
  }) async {
    try {
      final response = await _apiClient.dio.put(
        ApiEndpoints.expenseItem(expenseId),
        data: {
          'category_id': categoryId,
          'amount': amount,
          'note': note,
          'expense_date': expenseDate,
        },
      );

      if (response.data['success'] == true) {
        final updated = ExpenseModel.fromJson(response.data['data']['expense']);
        final index = _expenses.indexWhere((e) => e.id == expenseId);
        if (index != -1) {
          _expenses[index] = updated;
          notifyListeners();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  // 5. Delete Expense (with Undo support)
  Future<bool> deleteExpense(ExpenseModel expense) async {
    final originalIndex = _expenses.indexOf(expense);
    _expenses.remove(expense);
    notifyListeners();

    try {
      final response = await _apiClient.dio.delete(ApiEndpoints.expenseItem(expense.id));
      if (response.data['success'] == true) {
        return true;
      }
    } catch (_) {
      // Rollback if failure
      if (originalIndex != -1) {
        _expenses.insert(originalIndex, expense);
        notifyListeners();
      }
    }
    return false;
  }

  // 6. Fetch Summary Reports for Charts
  Future<void> fetchSummaryReports() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.expenseReports);
      if (response.data['success'] == true) {
        _summaryReport = ExpenseSummaryReport.fromJson(response.data['data']);
        notifyListeners();
      }
    } catch (_) {}
  }

  // 7. Create Custom Category
  Future<bool> createCategory({required String name, required String icon, required String color}) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.categories,
        data: {'name': name, 'icon': icon, 'color': color},
      );
      if (response.data['success'] == true) {
        final newCategory = ExpenseCategory.fromJson(response.data['data']['category']);
        _categories.add(newCategory);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }
}

