import 'package:flutter/material.dart';
import '../../models/item_model.dart';

class AddEditItemDialog extends StatefulWidget {
  final ItemModel? item;

  const AddEditItemDialog({super.key, this.item});

  @override
  State<AddEditItemDialog> createState() => _AddEditItemDialogState();
}

class _AddEditItemDialogState extends State<AddEditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _tagsController;
  late final TextEditingController _inUseByController;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _locationController = TextEditingController(text: item?.currentLocation ?? '');
    _tagsController = TextEditingController(text: item?.tags.join(', ') ?? '');
    _inUseByController = TextEditingController(text: item?.inUseBy ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _tagsController.dispose();
    _inUseByController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Item' : 'Save New Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Item Name
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g. Passport, Drill machine',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter item name';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Location
              if (!isEditing)
                TextFormField(
                  controller: _locationController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Where did you keep it?',
                    hintText: 'e.g. Blue file, second shelf of bedroom almirah',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter current location';
                    return null;
                  },
                ),
              if (!isEditing) const SizedBox(height: 12),

              // Tags
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  hintText: 'documents, travel, tools',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),

              // Lent To / In Use By
              TextFormField(
                controller: _inUseByController,
                decoration: const InputDecoration(
                  labelText: 'In Use / Lent To (optional)',
                  hintText: 'e.g. Rohan, Sister, In office',
                  prefixIcon: Icon(Icons.handshake_outlined),
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
              'name': _nameController.text.trim(),
              'current_location': _locationController.text.trim(),
              'tags': _tagsController.text.trim(),
              'in_use_by': _inUseByController.text.trim().isEmpty ? null : _inUseByController.text.trim(),
            });
          },
          child: Text(isEditing ? 'Save Changes' : 'Save Item'),
        ),
      ],
    );
  }
}
