import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/habit_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/habit_model.dart';
import '../../widgets/habit_card.dart';
import 'add_edit_habit_dialog.dart';
import 'habit_detail_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HabitProvider>().fetchHabits();
    });
  }

  void _openAddHabit() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddEditHabitDialog(),
    );

    if (result != null && mounted) {
      final success = await context.read<HabitProvider>().createHabit(
            name: result['name'],
            icon: result['icon'],
            color: result['color'],
            targetDaysPerWeek: result['target_days_per_week'],
            reminderTime: result['reminder_time'],
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit created successfully!'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  void _openEditHabit(HabitModel habit) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AddEditHabitDialog(habit: habit),
    );

    if (result != null && mounted) {
      await context.read<HabitProvider>().updateHabit(
            habitId: habit.id,
            name: result['name'],
            icon: result['icon'],
            color: result['color'],
            targetDaysPerWeek: result['target_days_per_week'],
            reminderTime: result['reminder_time'],
          );
    }
  }

  void _confirmDelete(HabitModel habit) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text('Are you sure you want to delete "${habit.name}" and all its logs?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              context.read<HabitProvider>().deleteHabit(habit.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habitProvider = context.watch<HabitProvider>();
    final todayFormatted = DateFormat('EEEE, MMM d').format(DateTime.now());

    final completedCount = habitProvider.habits.where((h) => h.isCompletedToday).length;
    final totalCount = habitProvider.habits.length;
    final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Habits", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(todayFormatted, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => habitProvider.fetchHabits(refresh: true),
        child: habitProvider.isLoading && habitProvider.habits.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Daily Progress Card
                  if (totalCount > 0)
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Daily Completion',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                ),
                                Text(
                                  '$completedCount / $totalCount completed',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress == 1.0 ? AppColors.success : AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.calendar_month_outlined, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  'Tap any habit to view its Month-wise Calendar & Heatmap',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Empty State
                  if (habitProvider.habits.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            Icon(Icons.emoji_events_outlined, size: 72, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              'No habits tracked yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Build consistent daily routines by adding your first habit.',
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _openAddHabit,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Your First Habit'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Habits List
                  ...habitProvider.habits.map((habit) {
                    return HabitCard(
                      habit: habit,
                      onCheckIn: () => habitProvider.toggleCheckIn(habit.id),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HabitDetailScreen(habit: habit),
                          ),
                        );
                      },
                      onEdit: () => _openEditHabit(habit),
                      onDelete: () => _confirmDelete(habit),
                    );
                  }),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddHabit,
        icon: const Icon(Icons.add),
        label: const Text('New Habit'),
      ),
    );
  }
}
