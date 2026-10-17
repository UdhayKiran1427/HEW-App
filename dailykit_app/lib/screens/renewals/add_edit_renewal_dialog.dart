import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/renewal_model.dart';
import '../../core/constants/app_colors.dart';

class AddEditRenewalDialog extends StatefulWidget {
  final RenewalModel? renewal;
  final Function({
    required String title,
    required String category,
    String? purchaseDate,
    required String expiryDate,
    double? amount,
    String? notes,
    required String remindBeforeDays,
  }) onSave;

  const AddEditRenewalDialog({
    super.key,
    this.renewal,
    required this.onSave,
  });

  @override
  State<AddEditRenewalDialog> createState() => _AddEditRenewalDialogState();
}

class _AddEditRenewalDialogState extends State<AddEditRenewalDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  String _selectedCategory = 'Recharge';
  DateTime? _purchaseDate;
  DateTime? _expiryDate;

  bool _alert5Days = true;
  bool _alert3Days = true;
  bool _alert1Day = true;

  final List<String> _categories = [
    'Recharge',
    'Warranty',
    'Subscription',
    'Insurance',
    'Service',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.renewal;
    _titleController = TextEditingController(text: r?.title ?? '');
    _amountController = TextEditingController(
      text: r?.amount != null ? r!.amount!.toStringAsFixed(0) : '',
    );
    _notesController = TextEditingController(text: r?.notes ?? '');

    if (r != null) {
      _selectedCategory = r.category;
      if (r.purchaseDate != null) {
        _purchaseDate = DateTime.tryParse(r.purchaseDate!);
      }
      _expiryDate = DateTime.tryParse(r.expiryDate);

      final days = r.remindBeforeDays.split(',').map((s) => s.trim()).toList();
      _alert5Days = days.contains('5');
      _alert3Days = days.contains('3');
      _alert1Day = days.contains('1');
    } else {
      // Default expiry date 30 days ahead
      _expiryDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isPurchase}) async {
    final now = DateTime.now();
    final initial = isPurchase
        ? (_purchaseDate ?? now)
        : (_expiryDate ?? now.add(const Duration(days: 30)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isPurchase) {
          _purchaseDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiry / renewal date.')),
      );
      return;
    }

    final alerts = <String>[];
    if (_alert5Days) alerts.add('5');
    if (_alert3Days) alerts.add('3');
    if (_alert1Day) alerts.add('1');
    final remindStr = alerts.isEmpty ? '1' : alerts.join(',');

    final double? amt = _amountController.text.trim().isNotEmpty
        ? double.tryParse(_amountController.text.trim())
        : null;

    final dateFormat = DateFormat('yyyy-MM-dd');

    widget.onSave(
      title: _titleController.text.trim(),
      category: _selectedCategory,
      purchaseDate: _purchaseDate != null ? dateFormat.format(_purchaseDate!) : null,
      expiryDate: dateFormat.format(_expiryDate!),
      amount: amt,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      remindBeforeDays: remindStr,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final isEditing = widget.renewal != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Renewal / Warranty' : 'Add Renewal / Warranty',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Selector
                        const Text(
                          'Category',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            final color = RenewalModel.getCategoryColor(cat);
                            return FilterChip(
                              label: Text(cat),
                              avatar: Icon(
                                RenewalModel.getCategoryIcon(cat),
                                size: 16,
                                color: isSelected ? Colors.white : color,
                              ),
                              selected: isSelected,
                              selectedColor: color,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : null,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (val) {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title / Item Name *',
                            hintText: 'e.g. Jio 84-Day Recharge, Laptop Warranty',
                            prefixIcon: Icon(Icons.label_outline_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Expiry / Renewal Date
                        InkWell(
                          onTap: () => _pickDate(isPurchase: false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_available_rounded, color: Colors.deepOrange),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Expiry / Renewal Date *',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        _expiryDate != null
                                            ? dateFormat.format(_expiryDate!)
                                            : 'Select date',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.calendar_month, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Purchase Date (Optional)
                        InkWell(
                          onTap: () => _pickDate(isPurchase: true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, color: Colors.blueGrey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Purchase Date (Optional)',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        _purchaseDate != null
                                            ? dateFormat.format(_purchaseDate!)
                                            : 'Not specified',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _purchaseDate != null ? null : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_purchaseDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() => _purchaseDate = null),
                                  )
                                else
                                  const Icon(Icons.calendar_month, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Amount (Optional)
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹) (Optional)',
                            hintText: 'e.g. 799',
                            prefixIcon: Icon(Icons.currency_rupee_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Remind Before Options
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.withAlpha(50)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.notifications_active, size: 18, color: Colors.deepOrange),
                                  SizedBox(width: 8),
                                  Text(
                                    'Advance Reminders:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _alert5Days,
                                        activeColor: Colors.deepOrange,
                                        onChanged: (val) => setState(() => _alert5Days = val ?? false),
                                      ),
                                      const Text('5 Days', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _alert3Days,
                                        activeColor: Colors.deepOrange,
                                        onChanged: (val) => setState(() => _alert3Days = val ?? false),
                                      ),
                                      const Text('3 Days', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _alert1Day,
                                        activeColor: Colors.deepOrange,
                                        onChanged: (val) => setState(() => _alert1Day = val ?? false),
                                      ),
                                      const Text('1 Day', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes / Serial No / Account ID (Optional)',
                            hintText: 'e.g. Bill uploaded, customer care # 198',
                            prefixIcon: Icon(Icons.notes_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isEditing ? 'Save Changes' : 'Add Tracker'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

