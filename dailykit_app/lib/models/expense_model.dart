import 'package:flutter/material.dart';

class ExpenseCategory {
  final int id;
  final String name;
  final String icon;
  final String color;
  final bool isDefault;

  ExpenseCategory({
    required this.id,
    required this.name,
    this.icon = 'category',
    this.color = '#2196F3',
    this.isDefault = false,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'General',
      icon: json['icon'] as String? ?? 'category',
      color: json['color'] as String? ?? '#2196F3',
      isDefault: json['is_default'] == 1 || json['is_default'] == true,
    );
  }

  static IconData getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'local_grocery_store':
        return Icons.local_grocery_store_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'school':
        return Icons.school_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

class ExpenseModel {
  final int id;
  final int userId;
  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final double amount;
  final String? note;
  final String expenseDate; // YYYY-MM-DD
  final String? createdAt;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.amount,
    this.note,
    required this.expenseDate,
    this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? 0,
      categoryId: json['category_id'] as int,
      categoryName: json['category_name'] as String? ?? 'General',
      categoryIcon: json['category_icon'] as String? ?? 'category',
      categoryColor: json['category_color'] as String? ?? '#2196F3',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      note: json['note'] as String?,
      expenseDate: json['expense_date'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }

  ExpenseModel copyWith({
    int? id,
    int? userId,
    int? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    double? amount,
    String? note,
    String? expenseDate,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt,
    );
  }
}

class ExpenseSummaryReport {
  final double today;
  final double thisWeek;
  final double thisMonth;
  final List<CategoryBreakdownItem> categoryBreakdown;
  final List<DailyTrendItem> dailyTrend;

  ExpenseSummaryReport({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.categoryBreakdown,
    required this.dailyTrend,
  });

  factory ExpenseSummaryReport.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final catList = json['category_breakdown'] as List? ?? [];
    final trendList = json['daily_trend'] as List? ?? [];

    return ExpenseSummaryReport(
      today: double.tryParse(summary['today'].toString()) ?? 0.0,
      thisWeek: double.tryParse(summary['this_week'].toString()) ?? 0.0,
      thisMonth: double.tryParse(summary['this_month'].toString()) ?? 0.0,
      categoryBreakdown: catList.map((c) => CategoryBreakdownItem.fromJson(c)).toList(),
      dailyTrend: trendList.map((d) => DailyTrendItem.fromJson(d)).toList(),
    );
  }
}

class CategoryBreakdownItem {
  final int id;
  final String name;
  final String color;
  final String icon;
  final double totalAmount;

  CategoryBreakdownItem({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.totalAmount,
  });

  factory CategoryBreakdownItem.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdownItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'General',
      color: json['color'] as String? ?? '#2196F3',
      icon: json['icon'] as String? ?? 'category',
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
    );
  }
}

class DailyTrendItem {
  final String date;
  final double total;

  DailyTrendItem({required this.date, required this.total});

  factory DailyTrendItem.fromJson(Map<String, dynamic> json) {
    return DailyTrendItem(
      date: json['expense_date'] as String? ?? '',
      total: double.tryParse(json['total'].toString()) ?? 0.0,
    );
  }
}

