// MODULE: EVENT PROFITABILITY REPORT SCREEN
// Last Updated: 2025-12-17 | Shows profit per order/event
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';
import '../report_preview_page.dart';

class EventProfitabilityScreen extends StatefulWidget {
  const EventProfitabilityScreen({super.key});

  @override
  State<EventProfitabilityScreen> createState() => _EventProfitabilityScreenState();
}

class _EventProfitabilityScreenState extends State<EventProfitabilityScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _orders = [];
  Map<int, Map<String, dynamic>> _profitability = {};
  bool _isLoading = true;
  String _firmId = 'DEFAULT';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    _firmId = prefs.getString('last_firm') ?? 'DEFAULT';
    
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    
    // Get orders in date range
    final db = await DatabaseHelper().database;
    final orders = await db.query(
      'orders',
      where: "firmId = ? AND date BETWEEN ? AND ?",
      whereArgs: [_firmId, startStr, endStr],
      orderBy: 'date DESC',
    );
    
    // Calculate profitability for each order
    final profMap = <int, Map<String, dynamic>>{};
    for (var order in orders) {
      final orderId = order['id'] as int;
      final profit = await DatabaseHelper().getEventProfitability(orderId, _firmId);
      profMap[orderId] = profit;
    }
    
    setState(() {
      _orders = orders;
      _profitability = profMap;
      _isLoading = false;
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) _startDate = _endDate;
        }
      });
      _loadData();
    }
  }

  void _exportReport() {
    if (_orders.isEmpty) return;
    
    final headers = ['Order ID', 'Date', 'Customer', 'Revenue', 'Cost', 'Profit', 'Margin %'];
    final rows = _orders.map((order) {
      final orderId = order['id'] as int;
      final profit = _profitability[orderId] ?? {};
      final revenue = (profit['revenue'] as num?)?.toDouble() ?? 0;
      final cost = (profit['totalCost'] as num?)?.toDouble() ?? 0;
      final netProfit = (profit['profit'] as num?)?.toDouble() ?? 0;
      final margin = (profit['margin'] as num?)?.toDouble() ?? 0;
      
      return [
        '#$orderId',
        order['date'] ?? '',
        order['customerName'] ?? 'Customer',
        revenue,
        cost,
        netProfit,
        '${margin.toStringAsFixed(1)}%',
      ];
    }).toList();
    
    // Add totals row
    double totalRevenue = 0, totalCost = 0, totalProfit = 0;
    for (var p in _profitability.values) {
      totalRevenue += (p['revenue'] as num?)?.toDouble() ?? 0;
      totalCost += (p['totalCost'] as num?)?.toDouble() ?? 0;
      totalProfit += (p['profit'] as num?)?.toDouble() ?? 0;
    }
    final avgMargin = totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0;
    rows.add(['TOTAL', '', '', totalRevenue, totalCost, totalProfit, '${avgMargin.toStringAsFixed(1)}%']);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          title: 'Event Profitability Report',
          subtitle: '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
          headers: headers,
          rows: rows,
          accentColor: Colors.purple,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate totals
    double totalRevenue = 0, totalCost = 0, totalProfit = 0;
    for (var p in _profitability.values) {
      totalRevenue += (p['revenue'] as num?)?.toDouble() ?? 0;
      totalCost += (p['totalCost'] as num?)?.toDouble() ?? 0;
      totalProfit += (p['profit'] as num?)?.toDouble() ?? 0;
    }
    final avgMargin = totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Profitability'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportReport,
            tooltip: 'Export',
          ),
        ],
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
                    // Date Range
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDate(true),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('From', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    Text(DateFormat('MMM d, yyyy').format(_startDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            Container(width: 1, height: 40, color: Colors.grey.shade300),
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDate(false),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('To', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      Text(DateFormat('MMM d, yyyy').format(_endDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(child: _buildSummaryCard('Revenue', totalRevenue, Colors.blue)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildSummaryCard('Cost', totalCost, Colors.red)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildSummaryCard('Profit', totalProfit, Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: avgMargin >= 20 ? Colors.green.shade50 : Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Average Margin: '),
                            Text(
                              '${avgMargin.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: avgMargin >= 20 ? Colors.green.shade700 : Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Orders List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${_orders.length} orders', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (_orders.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text('No orders in selected date range', style: TextStyle(color: Colors.grey.shade600)),
                          ),
                        ),
                      )
                    else
                      ..._orders.map((order) {
                        final orderId = order['id'] as int;
                        final profit = _profitability[orderId] ?? {};
                        final revenue = (profit['revenue'] as num?)?.toDouble() ?? 0;
                        final cost = (profit['totalCost'] as num?)?.toDouble() ?? 0;
                        final netProfit = (profit['profit'] as num?)?.toDouble() ?? 0;
                        final margin = (profit['margin'] as num?)?.toDouble() ?? 0;
                        
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            order['customerName'] ?? 'Customer',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            '${order['date']} | ${order['totalPax']} pax',
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: margin >= 20 ? Colors.green.shade100 : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${margin.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: margin >= 20 ? Colors.green.shade700 : Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildMiniStat('Revenue', revenue, Colors.blue),
                                    _buildMiniStat('Cost', cost, Colors.red),
                                    _buildMiniStat('Profit', netProfit, Colors.green),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String label, double amount, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
