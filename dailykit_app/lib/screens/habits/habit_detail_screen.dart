import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/habit_model.dart';
import '../../providers/habit_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/calendar_heatmap.dart';
import '../../widgets/weekly_habit_strip.dart';

class HabitDetailScreen extends StatefulWidget {
  final HabitModel habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  late HabitModel _habit;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    _loadFullDetails();
  }

  Future<void> _loadFullDetails() async {
    final provider = context.read<HabitProvider>();
    final detailed = await provider.fetchHabitDetails(_habit.id);
    if (detailed != null && mounted) {
      setState(() {
        _habit = detailed;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitColor = AppColors.fromHex(_habit.color);

    return Scaffold(
      appBar: AppBar(
        title: Text(_habit.name),
        actions: [
          IconButton(
            icon: Icon(
              _habit.isCompletedToday ? Icons.check_circle : Icons.check_circle_outline,
              color: _habit.isCompletedToday ? habitColor : null,
            ),
            tooltip: 'Toggle Today Check-in',
            onPressed: () async {
              await context.read<HabitProvider>().toggleCheckIn(_habit.id);
              _loadFullDetails();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFullDetails,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stat Cards Grid
                  Row(
                    children: [
                      _buildStatCard('Current Streak', '${_habit.currentStreak} days', '🔥', Colors.orange),
                      const SizedBox(width: 12),
                      _buildStatCard('Best Streak', '${_habit.longestStreak} days', '🏆', Colors.amber.shade700),
                      const SizedBox(width: 12),
                      _buildStatCard('Total Days', '${_habit.totalCompletions}', '⭐', habitColor),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Weekly Progress (Mon - Sun)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'This Week (Mon - Sun)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 14),
                          WeeklyHabitStrip(
                            completedLogs: _habit.logs,
                            habitColor: habitColor,
                            onDateTap: (date) async {
                              await context.read<HabitProvider>().toggleCheckIn(_habit.id, date: date);
                              _loadFullDetails();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Monthly Calendar Heatmap
                  CalendarHeatmap(
                    completedDates: _habit.logs,
                    habitColor: habitColor,
                    targetMonth: DateTime.now(),
                  ),
                  const SizedBox(height: 16),

                  // Reminder Card if active
                  if (_habit.reminderTime != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.alarm_on_rounded, color: AppColors.primary),
                        title: const Text('Daily Reminder Active'),
                        subtitle: Text('Notification scheduled at ${_habit.reminderTime}'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, String emoji, Color accent) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

