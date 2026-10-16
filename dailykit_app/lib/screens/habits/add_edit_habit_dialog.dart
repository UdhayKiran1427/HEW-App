import 'package:flutter/material.dart';
import '../../models/habit_model.dart';
import '../../core/constants/app_colors.dart';

class AddEditHabitDialog extends StatefulWidget {
  final HabitModel? habit;

  const AddEditHabitDialog({super.key, this.habit});

  @override
  State<AddEditHabitDialog> createState() => _AddEditHabitDialogState();
}

class _AddEditHabitDialogState extends State<AddEditHabitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;
  late int _targetDays;
  TimeOfDay? _reminderTime;

  final List<String> _icons = [
    'check_circle',
    'fitness_center',
    'menu_book',
    'water_drop',
    'self_improvement',
    'directions_run',
    'bedtime',
    'code',
    'music_note',
    'savings',
  ];

  final List<String> _colors = [
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#9C27B0', // Purple
    '#FF9800', // Orange
    '#E91E63', // Pink
    '#00BCD4', // Cyan
    '#FF5722', // Deep Orange
    '#673AB7', // Deep Purple
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.habit?.name ?? '');
    _selectedIcon = widget.habit?.icon ?? 'check_circle';
    _selectedColor = widget.habit?.color ?? '#4CAF50';
    _targetDays = widget.habit?.targetDaysPerWeek ?? 7;

    if (widget.habit?.reminderTime != null) {
      final parts = widget.habit!.reminderTime!.split(':');
      if (parts.length >= 2) {
        _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.habit != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Habit' : 'New Habit'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Habit Name
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Habit Name',
                  hintText: 'e.g. Read 20 pages',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter habit name';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Icon Picker
              const Text('Select Icon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons.map((iconName) {
                  final isSelected = _selectedIcon == iconName;
                  final currentColor = AppColors.fromHex(_selectedColor);
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = iconName),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? currentColor : Colors.grey.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        HabitModel.getIconData(iconName),
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        size: 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Color Picker
              const Text('Select Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colors.map((hex) {
                  final isSelected = _selectedColor == hex;
                  final color = AppColors.fromHex(hex);
                  return InkWell(
                    onTap: () => setState(() => _selectedColor = hex),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withAlpha(100), blurRadius: 6, spreadRadius: 2)]
                            : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Target Days Per Week
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Target Days / Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('$_targetDays days', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              Slider(
                value: _targetDays.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                label: '$_targetDays days',
                onChanged: (val) => setState(() => _targetDays = val.toInt()),
              ),
              const SizedBox(height: 8),

              // Reminder Time
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                title: const Text('Daily Reminder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _reminderTime != null
                      ? _reminderTime!.format(context)
                      : 'No reminder set',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: _reminderTime != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _reminderTime = null),
                      )
                    : TextButton(
                        onPressed: _pickTime,
                        child: const Text('Set Time'),
                      ),
                onTap: _pickTime,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            String? reminderString;
            if (_reminderTime != null) {
              final h = _reminderTime!.hour.toString().padLeft(2, '0');
              final m = _reminderTime!.minute.toString().padLeft(2, '0');
              reminderString = '$h:$m:00';
            }

            Navigator.pop(context, {
              'name': _nameController.text.trim(),
              'icon': _selectedIcon,
              'color': _selectedColor,
              'target_days_per_week': _targetDays,
              'reminder_time': reminderString,
            });
          },
          child: Text(isEditing ? 'Save Changes' : 'Create Habit'),
        ),
      ],
    );
  }
}

