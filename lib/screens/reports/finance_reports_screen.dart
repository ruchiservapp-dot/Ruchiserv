import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../db/database_helper.dart';

class FinanceReportsScreen extends StatefulWidget {
  const FinanceReportsScreen({super.key});

  @override
  State<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends State<FinanceReportsScreen> {
  bool _isLoading = true;
  String _selectedPeriod = 'Month'; // Month, Year
  
  double _totalIncome = 0;
  double _totalExpense = 0;
  List<Map<String, dynamic>> _trendData = [];

  final String _firmId = 'DEFAULT';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Determine Date Range
    final now = DateTime.now();
    DateTime startDate, endDate;
    String groupBy;
    
    if (_selectedPeriod == 'Month') {
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month + 1, 0);
      groupBy = 'day';
    } else {
      startDate = DateTime(now.year, 1, 1);
      endDate = DateTime(now.year, 12, 31);
      groupBy = 'month';
    }

    final summary = await DatabaseHelper().getFinanceSummary(_firmId, startDate.toIso8601String(), endDate.toIso8601String());
    final trend = await DatabaseHelper().getSummaryByPeriod(_firmId, startDate.toIso8601String(), endDate.toIso8601String(), groupBy);

    setState(() {
      _totalIncome = summary['income'] ?? 0;
      _totalExpense = summary['expense'] ?? 0;
      _trendData = trend;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Reports'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          DropdownButton<String>(
            value: _selectedPeriod,
            underline: const SizedBox(),
            items: ['Month', 'Year'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedPeriod = val);
                _loadData();
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Cards
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard("Income", _totalIncome, Colors.green)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildSummaryCard("Expense", _totalExpense, Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pie Chart
                  const Text("Income vs Expense", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    height: 250,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: _totalIncome,
                            title: '${((_totalIncome / (_totalIncome + _totalExpense)) * 100).toStringAsFixed(1)}%',
                            color: Colors.green,
                            radius: 50,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          PieChartSectionData(
                            value: _totalExpense,
                            title: '${((_totalExpense / (_totalIncome + _totalExpense)) * 100).toStringAsFixed(1)}%',
                            color: Colors.red,
                            radius: 50,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Trend Chart
                  const Text("Trends", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    height: 300,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: _trendData.isEmpty 
                      ? const Center(child: Text("No data for trends"))
                      : BarChart(
                          BarChartData(
                            gridData: FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 10)))),
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) {
                                if (val.toInt() < 0 || val.toInt() >= _trendData.length) return const Text('');
                                final dateStr = _trendData[val.toInt()]['period'];
                                // Format: 2024-10-25 or 2024-10
                                final date = DateTime.parse(_selectedPeriod == 'Month' ? dateStr : '$dateStr-01');
                                return Text(DateFormat(_selectedPeriod == 'Month' ? 'd' : 'MMM').format(date), style: const TextStyle(fontSize: 10));
                              })),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _trendData.asMap().entries.map((e) {
                              final index = e.key;
                              final data = e.value;
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(toY: (data['income'] as num).toDouble(), color: Colors.green, width: 8),
                                  BarChartRodData(toY: (data['expense'] as num).toDouble(), color: Colors.red, width: 8),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "₹${amount.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
