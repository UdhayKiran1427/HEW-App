import 'package:flutter/material.dart';
import '../../models/item_model.dart';
import '../../core/constants/app_colors.dart';

class MoveItemDialog extends StatefulWidget {
  final ItemModel item;

  const MoveItemDialog({super.key, required this.item});

  @override
  State<MoveItemDialog> createState() => _MoveItemDialogState();
}

class _MoveItemDialogState extends State<MoveItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newLocationController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _newLocationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.drive_file_move_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Move "${widget.item.name}"', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Location display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Location', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(widget.item.currentLocation, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // New Location Input
              TextFormField(
                controller: _newLocationController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'New Location',
                  hintText: 'e.g. Top drawer in office study desk',
                  prefixIcon: Icon(Icons.edit_location_alt_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter the new location';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Reason / Note (optional)',
                  hintText: 'e.g. Shifted after cleaning',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'new_location': _newLocationController.text.trim(),
              'notes': _notesController.text.trim(),
            });
          },
          child: const Text('Confirm Move'),
        ),
      ],
    );
  }
}

