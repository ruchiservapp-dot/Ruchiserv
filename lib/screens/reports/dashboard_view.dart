import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/finance_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardView extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const DashboardView({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  String _firmId = 'DEFAULT';
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _loadFirmId();
  }

  Future<void> _loadFirmId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _firmId = prefs.getString('last_firm') ?? 'DEFAULT';
        _isInit = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKPIRow(),
          const SizedBox(height: 24),
          _buildTrendSection(),
          const SizedBox(height: 24),
          _buildMixAndExpenseSection(),
          const SizedBox(height: 24),
          _buildTopDishesSection(),
        ],
      ),
    );
  }

  Widget _buildKPIRow() {
    return FutureBuilder<Map<String, dynamic>>(
      future: FinanceRepository().getKPIComparison(
          _firmId,
          DateFormat('yyyy-MM-dd').format(widget.startDate),
          DateFormat('yyyy-MM-dd').format(widget.endDate)),
      builder: (context, snapshot) {
        final Map<String, dynamic> data =
            (snapshot.data?['current'] as Map?)?.cast<String, dynamic>() ?? {};
        final revenue = (data['revenue'] as num?)?.toDouble() ?? 0.0;
        final cost = (data['cogs'] as num?)?.toDouble() ?? 0.0;
        final profit = (data['grossProfit'] as num?)?.toDouble() ?? 0.0;
        final margin = revenue > 0 ? (profit / revenue) * 100 : 0.0;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _buildKPICard(
                        'Total Revenue',
                        '₹${NumberFormat.simpleCurrency(decimalDigits: 0, name: '').format(revenue)}',
                        Icons.payments,
                        Colors.blue,
                        'Gross Sales')),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildKPICard(
                        'Gross Profit',
                        '₹${NumberFormat.simpleCurrency(decimalDigits: 0, name: '').format(profit)}',
                        Icons.trending_up,
                        Colors.green,
                        '${margin.toStringAsFixed(1)}% Margin')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildKPICard(
                        'Material Cost',
                        '₹${NumberFormat.simpleCurrency(decimalDigits: 0, name: '').format(cost)}',
                        Icons.inventory_2,
                        Colors.orange,
                        '${revenue > 0 ? (cost / revenue * 100).toStringAsFixed(1) : 0}% of Rev')),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildKPICard(
                        'Other Expenses',
                        '₹${NumberFormat.simpleCurrency(decimalDigits: 0, name: '').format((data['totalExpense'] ?? 0.0) - cost)}',
                        Icons.receipt_long,
                        Colors.redAccent,
                        'Fixed & Variable')),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrendSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FinanceRepository().getProfitabilityTrend(
          _firmId,
          DateFormat('yyyy-MM-dd').format(widget.startDate),
          DateFormat('yyyy-MM-dd').format(widget.endDate)),
      builder: (context, snapshot) {
        final trendData = snapshot.data ?? [];
        return _buildCard(
          title: 'Profitability Trend',
          child: Column(
            children: [
              SizedBox(
                height: 240,
                child: trendData.isEmpty
                    ? const Center(child: Text("No data for period"))
                    : Padding(
                        padding: const EdgeInsets.only(right: 16, top: 8),
                        child: LineChart(_getTrendData(trendData)),
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Revenue', Colors.blue),
                  const SizedBox(width: 24),
                  _buildLegendItem('Cost', Colors.orange),
                  const SizedBox(width: 24),
                  _buildLegendItem('Profit', Colors.green),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMixAndExpenseSection() {
    final start = DateFormat('yyyy-MM-dd').format(widget.startDate);
    final end = DateFormat('yyyy-MM-dd').format(widget.endDate);

    return Row(
      children: [
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: FinanceRepository().getKPIComparison(_firmId, start, end),
            builder: (context, snapshot) {
              final Map<String, dynamic> data =
                  (snapshot.data?['current'] as Map?)
                          ?.cast<String, dynamic>() ??
                      {};
              return _buildCard(
                title: 'Profitability Mix',
                height: 250,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 35,
                    sections: _buildProfitabilitySections(data),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future:
                FinanceRepository().getExpenseBreakdown(_firmId, start, end),
            builder: (context, snapshot) {
              final expenses = snapshot.data ?? [];
              return _buildCard(
                title: 'Expenses',
                height: 250,
                child: _buildExpenseBarChart(expenses),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopDishesSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: OrderRepository().getTopDishesReport(
          DateFormat('yyyy-MM-dd').format(widget.startDate),
          DateFormat('yyyy-MM-dd').format(widget.endDate),
          _firmId),
      builder: (context, snapshot) {
        final topDishes = (snapshot.data ?? []).take(5).toList();
        return _buildCard(
          title: 'Top Performing Items',
          child: Column(
            children: topDishes.isEmpty
                ? [
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("No items sold in this period"),
                    ))
                  ]
                : topDishes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final dish = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.1),
                                width: index == topDishes.length - 1 ? 0 : 1)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            child: Text('${index + 1}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(dish['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500))),
                          Text('${dish['orderCount'] ?? 0}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue)),
                          const SizedBox(width: 4),
                          const Text('sold',
                              style:
                                  TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    );
                  }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCard(
      {required String title, required Widget child, double? height}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.grey.shade100, blurRadius: 10)
          else
            const BoxShadow(color: Colors.black26, blurRadius: 4),
        ],
        border:
            Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.grey.shade700)),
          const SizedBox(height: 16),
          if (height != null) Expanded(child: child) else child,
        ],
      ),
    );
  }

  LineChartData _getTrendData(List<Map<String, dynamic>> dailyRevenue) {
    return LineChartData(
      lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withValues(alpha: 0.8))),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < dailyRevenue.length) {
                final dateStr = dailyRevenue[value.toInt()]['date'] as String;
                try {
                  final date = DateTime.parse(dateStr);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(DateFormat('dd/MM').format(date),
                        style: const TextStyle(fontSize: 9)),
                  );
                } catch (_) {
                  return const SizedBox();
                }
              }
              return const SizedBox();
            },
            interval: dailyRevenue.length > 7
                ? (dailyRevenue.length / 5).ceilToDouble()
                : 1,
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        _getLineData(dailyRevenue, Colors.blue, 'income'),
        _getLineData(dailyRevenue, Colors.orange, 'cost'),
        _getLineData(dailyRevenue, Colors.green, 'profit'),
      ],
    );
  }

  LineChartBarData _getLineData(
      List<Map<String, dynamic>> dailyRevenue, Color color, String key) {
    return LineChartBarData(
      spots: dailyRevenue
          .asMap()
          .entries
          .map(
              (e) => FlSpot(e.key.toDouble(), (e.value[key] as num).toDouble()))
          .toList(),
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
          show: key == 'income', color: color.withValues(alpha: 0.05)),
    );
  }

  Widget _buildExpenseBarChart(List<Map<String, dynamic>> expenseBreakdown) {
    if (expenseBreakdown.isEmpty)
      return const Center(child: Text("No expenses"));

    return BarChart(
      BarChartData(
        barGroups: expenseBreakdown.asMap().entries.map((e) {
          final total = (e.value['total'] as num).toDouble();
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: total,
                color: _getExpenseColor(e.value['groupName']),
                width: 14,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < expenseBreakdown.length) {
                  final name = expenseBreakdown[index]['groupName'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                        name.substring(0, name.length > 5 ? 5 : name.length),
                        style: const TextStyle(fontSize: 8)),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withValues(alpha: 0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final name = expenseBreakdown[groupIndex]['groupName'];
              return BarTooltipItem(
                '$name\n₹${NumberFormat.compact().format(rod.toY)}',
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getExpenseColor(String groupName) {
    switch (groupName) {
      case 'Materials':
        return Colors.orange;
      case 'Staff':
        return Colors.blue;
      case 'Logistics':
        return Colors.purple;
      case 'Utilities':
        return Colors.amber;
      default:
        return Colors.redAccent;
    }
  }

  List<PieChartSectionData> _buildProfitabilitySections(
      Map<String, dynamic> metrics) {
    final revenue = metrics['revenue'] ?? 1.0;
    final profit = metrics['grossProfit'] ?? 0.0;
    final cogs = metrics['cogs'] ?? 0.0;
    final otherExpenses = (metrics['totalExpense'] ?? 0.0) - cogs;

    List<PieChartSectionData> sections = [];

    // Material Cost (Orange)
    if (cogs > 0) {
      sections.add(PieChartSectionData(
        color: Colors.orange,
        value: cogs,
        title: '${(cogs / revenue * 100).toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    // Other Expenses (Red/Amber)
    if (otherExpenses > 0) {
      sections.add(PieChartSectionData(
        color: Colors.redAccent,
        value: otherExpenses,
        title: '${(otherExpenses / revenue * 100).toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    // Net Profit (Green)
    if (profit > 0) {
      sections.add(PieChartSectionData(
        color: Colors.green,
        value: profit,
        title: '${(profit / revenue * 100).toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    return sections;
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildKPICard(
      String title, String value, IconData icon, Color color, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          if (!isDark)
            BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          else
            const BoxShadow(color: Colors.black45, blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Icon(Icons.more_horiz,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  size: 18),
            ],
          ),
          const SizedBox(height: 16),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
              const SizedBox(width: 4),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 10, color: color, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ],
          ),
        ],
      ),
    );
  }
}
