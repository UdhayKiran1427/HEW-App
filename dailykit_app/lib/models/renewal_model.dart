import 'package:flutter/material.dart';

class RenewalModel {
  final int id;
  final int userId;
  final String title;
  final String category; // Recharge, Warranty, Subscription, Insurance, Service, Other
  final String? purchaseDate; // YYYY-MM-DD
  final String expiryDate; // YYYY-MM-DD
  final double? amount;
  final String? notes;
  final String remindBeforeDays; // e.g. "5,3,1"
  final bool isRenewed;
  final int daysRemaining;
  final String status; // active, expiring_soon, expired

  RenewalModel({
    required this.id,
    required this.userId,
    required this.title,
    this.category = 'Subscription',
    this.purchaseDate,
    required this.expiryDate,
    this.amount,
    this.notes,
    this.remindBeforeDays = '5,3,1',
    this.isRenewed = false,
    required this.daysRemaining,
    required this.status,
  });

  factory RenewalModel.fromJson(Map<String, dynamic> json) {
    return RenewalModel(
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'Subscription',
      purchaseDate: json['purchase_date'] as String?,
      expiryDate: json['expiry_date'] as String? ?? '',
      amount: json['amount'] != null ? double.tryParse(json['amount'].toString()) : null,
      notes: json['notes'] as String?,
      remindBeforeDays: json['remind_before_days'] as String? ?? '5,3,1',
      isRenewed: json['is_renewed'] == 1 || json['is_renewed'] == true,
      daysRemaining: json['days_remaining'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
    );
  }

  RenewalModel copyWith({
    int? id,
    int? userId,
    String? title,
    String? category,
    String? purchaseDate,
    String? expiryDate,
    double? amount,
    String? notes,
    String? remindBeforeDays,
    bool? isRenewed,
    int? daysRemaining,
    String? status,
  }) {
    return RenewalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      remindBeforeDays: remindBeforeDays ?? this.remindBeforeDays,
      isRenewed: isRenewed ?? this.isRenewed,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      status: status ?? this.status,
    );
  }

  static IconData getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'recharge':
        return Icons.phone_android_rounded;
      case 'warranty':
        return Icons.verified_user_rounded;
      case 'subscription':
        return Icons.subscriptions_rounded;
      case 'insurance':
        return Icons.shield_rounded;
      case 'service':
        return Icons.build_circle_rounded;
      default:
        return Icons.event_repeat_rounded;
    }
  }

  static Color getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'recharge':
        return const Color(0xFF2196F3);
      case 'warranty':
        return const Color(0xFFFF9800);
      case 'subscription':
        return const Color(0xFF9C27B0);
      case 'insurance':
        return const Color(0xFF4CAF50);
      case 'service':
        return const Color(0xFF009688);
      default:
        return const Color(0xFF607D8B);
    }
  }
}

