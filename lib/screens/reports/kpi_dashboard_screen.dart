// MODULE: KPI DASHBOARD SCREEN
// Revenue, Margin %, Order Count, Avg Order Value with period comparison
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';

class KPIDashboardScreen extends StatefulWidget {
  const KPIDashboardScreen({super.key});

  @override
  State<KPIDashboardScreen> createState() => _KPIDashboardScreenState();
}

class _KPIDashboardScreenState extends State<KPIDashboardScreen> {
  String _selectedPeriod = 'This Month';
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String _firmId = 'DEFAULT';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  (String, String) _getDateRange() {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;
    
    switch (_selectedPeriod) {
      case 'This Week':
        start = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'This Quarter':
        final quarter = ((now.month - 1) ~/ 3) * 3 + 1;
        start = DateTime(now.year, quarter, 1);
        break;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }
    
    return (
      DateFormat('yyyy-MM-dd').format(start),
      DateFormat('yyyy-MM-dd').format(end),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    _firmId = prefs.getString('last_firm') ?? 'DEFAULT';
    
    final (startDate, endDate) = _getDateRange();
    final data = await DatabaseHelper().getKPIComparison(_firmId, startDate, endDate);
    
    setState(() {
      _data = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = (_data?['current'] as Map<String, dynamic>?) ?? {};
    final changes = (_data?['changes'] as Map<String, dynamic>?) ?? {};
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('KPI Dashboard'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period Selector
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.date_range, color: Colors.deepPurple.shade400),
                            const SizedBox(width: 12),
                            const Text('Period:', style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _selectedPeriod,
                              underline: const SizedBox(),
                              items: ['This Week', 'This Month', 'This Quarter', 'This Year']
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedPeriod = val);
                                  _loadData();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // KPI Cards Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildKPICard(
                          title: 'Revenue',
                          value: '₹${_formatNumber((current['revenue'] as num?)?.toDouble() ?? 0)}',
                          change: (changes['revenue'] as num?)?.toDouble() ?? 0,
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                        _buildKPICard(
                          title: 'Gross Margin',
                          value: '${((current['grossMargin'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
                          change: (changes['grossMargin'] as num?)?.toDouble() ?? 0,
                          icon: Icons.trending_up,
                          color: Colors.blue,
                          isPercentageChange: true,
                        ),
                        _buildKPICard(
                          title: 'Orders',
                          value: '${(current['orderCount'] as num?)?.toInt() ?? 0}',
                          change: (changes['orderCount'] as num?)?.toDouble() ?? 0,
                          icon: Icons.receipt_long,
                          color: Colors.orange,
                        ),
                        _buildKPICard(
                          title: 'Avg Order Value',
                          value: '₹${_formatNumber((current['avgOrderValue'] as num?)?.toDouble() ?? 0)}',
                          change: (changes['avgOrderValue'] as num?)?.toDouble() ?? 0,
                          icon: Icons.shopping_cart,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Additional Metrics
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Additional Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 16),
                            _buildMetricRow('Total Pax Served', '${(current['totalPax'] as num?)?.toInt() ?? 0}', Icons.people),
                            const Divider(),
                            _buildMetricRow('Gross Profit', '₹${_formatNumber((current['grossProfit'] as num?)?.toDouble() ?? 0)}', Icons.money),
                            const Divider(),
                            _buildMetricRow('Material Cost (COGS)', '₹${_formatNumber((current['cogs'] as num?)?.toDouble() ?? 0)}', Icons.inventory),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Info Note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey.shade600, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Trend arrows compare with the previous period of same duration',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatNumber(double num) {
    if (num >= 100000) {
      return '${(num / 100000).toStringAsFixed(1)}L';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toStringAsFixed(0);
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required double change,
    required IconData icon,
    required Color color,
    bool isPercentageChange = false,
  }) {
    final isPositive = change >= 0;
    final changeText = isPercentageChange
        ? '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}pp'
        : '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%';
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                if (change != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          changeText,
                          style: TextStyle(
                            fontSize: 10,
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
