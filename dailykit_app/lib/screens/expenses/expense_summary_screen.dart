import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/expense_model.dart';

class ExpenseSummaryScreen extends StatefulWidget {
  const ExpenseSummaryScreen({super.key});

  @override
  State<ExpenseSummaryScreen> createState() => _ExpenseSummaryScreenState();
}

class _ExpenseSummaryScreenState extends State<ExpenseSummaryScreen> {
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().fetchSummaryReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final report = provider.summaryReport;
    final currency = settings.currency;

    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchSummaryReports(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Totals Summary Cards
          Row(
            children: [
              _buildTotalCard('Today', CurrencyFormatter.format(report.today, currency: currency), AppColors.primary),
              const SizedBox(width: 8),
              _buildTotalCard('This Week', CurrencyFormatter.format(report.thisWeek, currency: currency), AppColors.secondary),
              const SizedBox(width: 8),
              _buildTotalCard('This Month', CurrencyFormatter.format(report.thisMonth, currency: currency), Colors.deepPurple),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Category Breakdown (Pie Chart)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category Breakdown (This Month)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (report.categoryBreakdown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No expense data for this month.')),
                    )
                  else
                    Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      _touchedPieIndex = -1;
                                      return;
                                    }
                                    _touchedPieIndex =
                                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: _generatePieSections(report.categoryBreakdown),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Legend List
                        ...report.categoryBreakdown.map((item) {
                          final color = AppColors.fromHex(item.color);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13))),
                                Text(
                                  CurrencyFormatter.format(item.totalAmount, currency: currency),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Daily Spending Trend (Bar Chart)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Trend (Last 7 Days)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (report.dailyTrend.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No daily activity found.')),
                    )
                  else
                    SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _calculateMaxY(report.dailyTrend),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final date = report.dailyTrend[group.x].date;
                                return BarTooltipItem(
                                  '$date\n${CurrencyFormatter.format(rod.toY, currency: currency)}',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < report.dailyTrend.length) {
                                    final d = report.dailyTrend[idx].date;
                                    // Show DD
                                    final parts = d.split('-');
                                    return Text(
                                      parts.length == 3 ? parts[2] : '$idx',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(report.dailyTrend.length, (i) {
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: report.dailyTrend[i].total,
                                  color: AppColors.primary,
                                  width: 16,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(String title, String amount, Color accentColor) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amount,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _generatePieSections(List<CategoryBreakdownItem> items) {
    return List.generate(items.length, (i) {
      final isTouched = i == _touchedPieIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final item = items[i];

      return PieChartSectionData(
        color: AppColors.fromHex(item.color),
        value: item.totalAmount,
        title: '${item.name[0]}',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  double _calculateMaxY(List<DailyTrendItem> items) {
    double max = 100;
    for (final item in items) {
      if (item.total > max) max = item.total;
    }
    return max * 1.25;
  }
}

