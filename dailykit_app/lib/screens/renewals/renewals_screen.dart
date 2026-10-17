import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/renewal_model.dart';
import '../../providers/renewal_provider.dart';
import '../../widgets/renewal_card.dart';
import '../../widgets/voice_assistant_sheet.dart';
import '../../core/utils/hinglish_voice_parser.dart';
import 'add_edit_renewal_dialog.dart';

class RenewalsScreen extends StatefulWidget {
  const RenewalsScreen({super.key});

  @override
  State<RenewalsScreen> createState() => _RenewalsScreenState();
}

class _RenewalsScreenState extends State<RenewalsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statusFilters = ['All', 'Expiring Soon', 'Active', 'Expired'];
  final List<String> _categoryFilters = [
    'All',
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RenewalProvider>().fetchRenewals();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddEditRenewalDialog(
        onSave: ({
          required String title,
          required String category,
          String? purchaseDate,
          required String expiryDate,
          double? amount,
          String? notes,
          required String remindBeforeDays,
        }) async {
          final success = await context.read<RenewalProvider>().addRenewal(
                title: title,
                category: category,
                purchaseDate: purchaseDate,
                expiryDate: expiryDate,
                amount: amount,
                notes: notes,
                remindBeforeDays: remindBeforeDays,
              );
          if (mounted && success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Renewal/Warranty added successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  void _openEditDialog(RenewalModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditRenewalDialog(
        renewal: item,
        onSave: ({
          required String title,
          required String category,
          String? purchaseDate,
          required String expiryDate,
          double? amount,
          String? notes,
          required String remindBeforeDays,
        }) async {
          final success = await context.read<RenewalProvider>().updateRenewal(
                id: item.id,
                title: title,
                category: category,
                purchaseDate: purchaseDate,
                expiryDate: expiryDate,
                amount: amount,
                notes: notes,
                remindBeforeDays: remindBeforeDays,
                isRenewed: item.isRenewed,
              );
          if (mounted && success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Updated successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(RenewalModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tracker?'),
        content: Text('Are you sure you want to delete "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await context.read<RenewalProvider>().deleteRenewal(item.id);
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deleted successfully')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RenewalProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter items locally by search query
    var filteredList = provider.renewals;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredList = filteredList.where((r) {
        return r.title.toLowerCase().contains(q) ||
            r.category.toLowerCase().contains(q) ||
            (r.notes != null && r.notes!.toLowerCase().contains(q));
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Renewals & Warranties',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: AppColors.primary),
            tooltip: 'Voice Add Renewal (Hinglish/English)',
            onPressed: () => VoiceAssistantSheet.show(context, preferredType: VoiceActionType.renewal),
          ),
          if (provider.expiringSoonCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepOrange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.deepOrange),
                  const SizedBox(width: 4),
                  Text(
                    '${provider.expiringSoonCount} Due Soon',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Tracker'),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchRenewals(refresh: true),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search recharge, warranty, bills...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),

            // Status Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: _statusFilters.map((status) {
                  final isSelected = provider.selectedStatusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withAlpha(30),
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => provider.setStatusFilter(status),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: _categoryFilters.map((cat) {
                  final isSelected = provider.selectedCategoryFilter == cat;
                  final catColor = cat == 'All'
                      ? AppColors.primary
                      : RenewalModel.getCategoryColor(cat);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: catColor.withAlpha(30),
                      labelStyle: TextStyle(
                        color: isSelected ? catColor : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                      onSelected: (_) => provider.setCategoryFilter(cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 12),

            // Body List / Loading / Empty
            Expanded(
              child: provider.isLoading && provider.renewals.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredList.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_repeat_rounded,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No trackers matching "$_searchQuery"'
                                        : 'No Renewals or Warranties added yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add your Mobile Recharge, Device Warranty, Car Insurance, or Subscriptions to get alerts 5, 3 & 1 days before expiry!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: _openAddDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add First Tracker'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final item = filteredList[index];
                            return RenewalCard(
                              renewal: item,
                              onEdit: () => _openEditDialog(item),
                              onDelete: () => _confirmDelete(item),
                              onToggleRenewed: () {
                                context.read<RenewalProvider>().updateRenewal(
                                      id: item.id,
                                      title: item.title,
                                      category: item.category,
                                      purchaseDate: item.purchaseDate,
                                      expiryDate: item.expiryDate,
                                      amount: item.amount,
                                      notes: item.notes,
                                      remindBeforeDays: item.remindBeforeDays,
                                      isRenewed: !item.isRenewed,
                                    );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

