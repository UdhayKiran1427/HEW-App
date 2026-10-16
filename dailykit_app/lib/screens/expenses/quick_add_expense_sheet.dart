import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/expense_model.dart';

class QuickAddExpenseSheet extends StatefulWidget {
  final ExpenseModel? expenseToEdit;

  const QuickAddExpenseSheet({super.key, this.expenseToEdit});

  @override
  State<QuickAddExpenseSheet> createState() => _QuickAddExpenseSheetState();
}

class _QuickAddExpenseSheetState extends State<QuickAddExpenseSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _focusNode = FocusNode();

  int? _selectedCategoryId;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final expense = widget.expenseToEdit;

    if (expense != null) {
      _amountController.text = expense.amount.toString();
      _noteController.text = expense.note ?? '';
      _selectedCategoryId = expense.categoryId;
      _selectedDate = DateTime.tryParse(expense.expenseDate) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
      // Preselect last-used category from provider
      final provider = context.read<ExpenseProvider>();
      _selectedCategoryId = provider.lastUsedCategoryId;
    }

    // Auto-focus amount field for <5s quick entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveExpense() async {
    final amountText = _amountController.text.trim();
    final double? amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: AppColors.error),
      );
      return;
    }

    final provider = context.read<ExpenseProvider>();

    // If no category selected yet, pick first available category
    int categoryId = _selectedCategoryId ??
        (provider.categories.isNotEmpty ? provider.categories.first.id : 1);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    if (widget.expenseToEdit != null) {
      await provider.updateExpense(
        expenseId: widget.expenseToEdit!.id,
        categoryId: categoryId,
        amount: amount,
        note: _noteController.text.trim(),
        expenseDate: dateStr,
      );
    } else {
      await provider.addExpense(
        categoryId: categoryId,
        amount: amount,
        note: _noteController.text.trim(),
        expenseDate: dateStr,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final currencySymbol = CurrencyFormatter.getSymbol(settings.currency);
    final categories = provider.categories;

    // Default to first category if none selected
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.expenseToEdit != null ? 'Edit Expense' : 'Quick Add Expense',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // Date Button
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(DateFormat('MMM d').format(_selectedDate)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount Input Field (Auto-focused, large font)
          TextField(
            controller: _amountController,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveExpense(),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8, top: 4),
                child: Text(
                  currencySymbol,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              hintText: '0.00',
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),

          // Category Selector Chips (horizontal scroll)
          const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = _selectedCategoryId == cat.id;
                final catColor = AppColors.fromHex(cat.color);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: Icon(
                      ExpenseCategory.getIconData(cat.icon),
                      size: 16,
                      color: isSelected ? Colors.white : catColor,
                    ),
                    label: Text(cat.name),
                    selectedColor: catColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() => _selectedCategoryId = cat.id);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Optional Note Field
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'Optional note (e.g. Lunch with team)',
              prefixIcon: const Icon(Icons.edit_note_rounded),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          // Save Expense Button (<5s submission)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saveExpense,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              widget.expenseToEdit != null ? 'Update Expense' : 'Save Expense',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

