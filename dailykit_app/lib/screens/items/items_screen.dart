import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/item_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/item_model.dart';
import '../../widgets/item_card.dart';
import 'add_edit_item_dialog.dart';
import 'move_item_dialog.dart';
import 'item_detail_screen.dart';
import '../../widgets/voice_assistant_sheet.dart';
import '../../core/utils/hinglish_voice_parser.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  final List<String> _popularTags = [
    'documents',
    'electronics',
    'tools',
    'keys',
    'important',
    'office',
    'travel',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemProvider>().fetchItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<ItemProvider>().fetchItems(searchQuery: query);
    });
  }

  void _openAddItem() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddEditItemDialog(),
    );

    if (result != null && mounted) {
      final success = await context.read<ItemProvider>().addItem(
            name: result['name'],
            currentLocation: result['current_location'],
            tags: result['tags'],
            inUseBy: result['in_use_by'],
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item saved! You can always find it here.'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  void _openMoveItem(ItemModel item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => MoveItemDialog(item: item),
    );

    if (result != null && mounted) {
      await context.read<ItemProvider>().moveItem(
            itemId: item.id,
            newLocation: result['new_location'],
            notes: result['notes'],
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New location recorded!'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  void _openEditItem(ItemModel item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AddEditItemDialog(item: item),
    );

    if (result != null && mounted) {
      await context.read<ItemProvider>().updateItem(
            itemId: item.id,
            name: result['name'],
            tags: result['tags'],
            inUseBy: result['in_use_by'],
          );
    }
  }

  void _confirmDelete(ItemModel item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}" and its location history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              context.read<ItemProvider>().deleteItem(item.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Where I Kept It'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: AppColors.primary),
            tooltip: 'Voice Add Item (Hinglish/English)',
            onPressed: () => VoiceAssistantSheet.show(context, preferredType: VoiceActionType.whereKept),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Fast Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by item name, location, or tag...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ItemProvider>().fetchItems(searchQuery: '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          // 2. Popular Tag Filters (horizontal chips)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: provider.selectedTag == null,
                    showCheckmark: false,
                    onSelected: (_) => provider.setTagFilter(null),
                  ),
                ),
                ..._popularTags.map((tag) {
                  final isSelected = provider.selectedTag == tag;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('#$tag'),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (_) => provider.setTagFilter(isSelected ? null : tag),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3. Items List / Empty State
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.fetchItems(refresh: true),
              child: provider.isLoading && provider.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 72, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'No items match "${_searchController.text}"'
                                      : 'No items saved yet',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Never forget where you placed your passport, keys, or tools.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _openAddItem,
                                  icon: const Icon(Icons.add_location_alt_rounded),
                                  label: const Text('Save Your First Item'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: provider.items.length,
                          itemBuilder: (context, index) {
                            final item = provider.items[index];
                            return ItemCard(
                              item: item,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ItemDetailScreen(item: item),
                                  ),
                                );
                              },
                              onMove: () => _openMoveItem(item),
                              onEdit: () => _openEditItem(item),
                              onDelete: () => _confirmDelete(item),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddItem,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Save Item'),
      ),
    );
  }
}
