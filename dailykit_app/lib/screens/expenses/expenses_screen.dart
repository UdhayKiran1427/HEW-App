import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/expense_model.dart';
import 'quick_add_expense_sheet.dart';
import 'expense_summary_screen.dart';
import '../../widgets/voice_assistant_sheet.dart';
import '../../core/utils/hinglish_voice_parser.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().fetchCategories();
      context.read<ExpenseProvider>().fetchExpenses();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openQuickAdd({ExpenseModel? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => QuickAddExpenseSheet(expenseToEdit: expense),
    );
  }

  void _confirmDelete(ExpenseModel expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete this ${expense.categoryName} expense of ₹${expense.amount.toStringAsFixed(0)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ExpenseProvider>().deleteExpense(expense);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Expense deleted successfully')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Custom Category'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Gym, Books, Gaming',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await context.read<ExpenseProvider>().createCategory(
                      name: nameCtrl.text.trim(),
                      icon: 'category',
                      color: '#009688',
                    );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: AppColors.primary),
            tooltip: 'Voice Add Expense (Hinglish/English)',
            onPressed: () => VoiceAssistantSheet.show(context, preferredType: VoiceActionType.expense),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Add Custom Category',
            onPressed: _openAddCategoryDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Transactions'),
            Tab(icon: Icon(Icons.pie_chart_rounded), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionList(),
          const ExpenseSummaryScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openQuickAdd(),
        icon: const Icon(Icons.bolt_rounded),
        label: const Text('Quick Add'),
      ),
    );
  }

  Widget _buildTransactionList() {
    final provider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;

    if (provider.isLoading && provider.expenses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 72, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No expenses recorded yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap Quick Add to record an expense in under 5 seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _openQuickAdd(),
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Quick Add Expense'),
              ),
            ],
          ),
        ),
      );
    }

    // Group expenses by date
    final Map<String, List<ExpenseModel>> grouped = {};
    for (final exp in provider.expenses) {
      final dateKey = exp.expenseDate;
      grouped.putIfAbsent(dateKey, () => []).add(exp);
    }

    final dates = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: () => provider.fetchExpenses(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final dateStr = dates[index];
          final list = grouped[dateStr]!;
          final dayTotal = list.fold<double>(0.0, (sum, item) => sum + item.amount);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header with Day Total
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDateHeader(dateStr),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700),
                    ),
                    Text(
                      CurrencyFormatter.format(dayTotal, currency: currency),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                    ),
                  ],
                ),
              ),

              // Expenses in this date
              ...list.map((expense) {
                final catColor = AppColors.fromHex(expense.categoryColor);

                return Dismissible(
                  key: Key('expense_${expense.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                  ),
                  onDismissed: (_) {
                    provider.deleteExpense(expense);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deleted ${expense.categoryName} expense'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            provider.addExpense(
                              categoryId: expense.categoryId,
                              amount: expense.amount,
                              note: expense.note,
                              expenseDate: expense.expenseDate,
                            );
                          },
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _openQuickAdd(expense: expense),
                      leading: CircleAvatar(
                        backgroundColor: catColor.withAlpha(35),
                        child: Icon(
                          ExpenseCategory.getIconData(expense.categoryIcon),
                          color: catColor,
                        ),
                      ),
                      title: Text(
                        expense.categoryName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: expense.note != null && expense.note!.isNotEmpty
                          ? Text(expense.note!, style: const TextStyle(fontSize: 12))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            CurrencyFormatter.format(expense.amount, currency: currency),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _openQuickAdd(expense: expense);
                              } else if (val == 'delete') {
                                _confirmDelete(expense);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: AppColors.error)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  String _formatDateHeader(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return 'Today';
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
        return 'Yesterday';
      }
      return DateFormat('EEE, MMM d').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
