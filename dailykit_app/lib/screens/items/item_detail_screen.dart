import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/item_model.dart';
import '../../providers/item_provider.dart';
import '../../core/constants/app_colors.dart';
import 'move_item_dialog.dart';
import 'add_edit_item_dialog.dart';

class ItemDetailScreen extends StatefulWidget {
  final ItemModel item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late ItemModel _item;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final provider = context.read<ItemProvider>();
    final details = await provider.fetchItemDetails(_item.id);
    if (details != null && mounted) {
      setState(() {
        _item = details;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _openMoveDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => MoveItemDialog(item: _item),
    );

    if (result != null && mounted) {
      final success = await context.read<ItemProvider>().moveItem(
            itemId: _item.id,
            newLocation: result['new_location'],
            notes: result['notes'],
          );

      if (success && mounted) {
        _loadDetails();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated and recorded in history!'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  void _openEditDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AddEditItemDialog(item: _item),
    );

    if (result != null && mounted) {
      await context.read<ItemProvider>().updateItem(
            itemId: _item.id,
            name: result['name'],
            tags: result['tags'],
            inUseBy: result['in_use_by'],
          );
      _loadDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Item',
            onPressed: _openEditDialog,
          ),
          IconButton(
            icon: const Icon(Icons.drive_file_move_rounded, color: AppColors.primary),
            tooltip: 'Mark as Moved',
            onPressed: _openMoveDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Current Location Highlight Card
                  Card(
                    color: AppColors.primary.withAlpha(20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.location_on_rounded, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'CURRENT LOCATION',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _item.currentLocation,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            onPressed: _openMoveDialog,
                            icon: const Icon(Icons.drive_file_move_outline, size: 18),
                            label: const Text('Mark as Moved'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lent To / In Use Card
                  if (_item.inUseBy != null && _item.inUseBy!.isNotEmpty)
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.amber,
                          child: Icon(Icons.handshake_rounded, color: Colors.white),
                        ),
                        title: const Text('Currently Lent / In Use', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text(
                          _item.inUseBy!,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (_item.inUseBy != null && _item.inUseBy!.isNotEmpty) const SizedBox(height: 16),

                  // Tags
                  if (_item.tags.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _item.tags.map((t) {
                                return Chip(
                                  label: Text('#$t', style: const TextStyle(fontSize: 12)),
                                  backgroundColor: Colors.grey.withAlpha(30),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Location History Timeline
                  const Text(
                    'Location History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_item.history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No previous location changes recorded.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._item.history.map((h) {
                      String formattedDate = h.changedAt;
                      try {
                        final parsed = DateTime.parse(h.changedAt);
                        formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(parsed);
                      } catch (_) {}

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history_rounded, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      h.previousLocation,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      h.newLocation,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              if (h.notes != null && h.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Note: ${h.notes!}',
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

