// MODULE: PROFIT & LOSS REPORT SCREEN
// Last Updated: 2025-12-17 | Features: P&L with income/expense grouping, export
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';
import '../report_preview_page.dart';

class PLReportScreen extends StatefulWidget {
  const PLReportScreen({super.key});

  @override
  State<PLReportScreen> createState() => _PLReportScreenState();
}

class _PLReportScreenState extends State<PLReportScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  Map<String, dynamic>? _plData;
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
    
    final plData = await DatabaseHelper().getProfitLossSummary(_firmId, startStr, endStr);
    
    setState(() {
      _plData = plData;
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
    if (_plData == null) return;
    
    final income = (_plData!['income'] as List?) ?? [];
    final expenses = (_plData!['expenses'] as List?) ?? [];
    
    final headers = ['Category', 'Amount (₹)'];
    final rows = <List<dynamic>>[];
    
    // Add income header
    rows.add(['--- INCOME ---', '']);
    for (var i in income) {
      rows.add([i['category'] ?? 'Other', i['total'] ?? 0]);
    }
    rows.add(['Total Income', _plData!['totalIncome'] ?? 0]);
    
    // Add expense header
    rows.add(['--- EXPENSES ---', '']);
    for (var e in expenses) {
      rows.add([e['expenseGroup'] ?? 'Other', e['total'] ?? 0]);
    }
    rows.add(['Total Expenses', _plData!['totalExpense'] ?? 0]);
    
    // Add profit
    rows.add(['', '']);
    rows.add(['NET PROFIT', _plData!['netProfit'] ?? 0]);
    rows.add(['Profit Margin %', '${(_plData!['profitMargin'] as num?)?.toStringAsFixed(1) ?? 0}%']);
    
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          title: 'Profit & Loss Statement',
          subtitle: '$startStr to $endStr',
          headers: headers,
          rows: rows,
          accentColor: Colors.green,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalIncome = (_plData?['totalIncome'] as num?)?.toDouble() ?? 0;
    final totalExpense = (_plData?['totalExpense'] as num?)?.toDouble() ?? 0;
    final netProfit = (_plData?['netProfit'] as num?)?.toDouble() ?? 0;
    final profitMargin = (_plData?['profitMargin'] as num?)?.toDouble() ?? 0;
    final income = (_plData?['income'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final expenses = (_plData?['expenses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Loss'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportReport,
            tooltip: 'Export Report',
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
                    // Date Range Picker
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
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('MMM d, yyyy').format(_startDate),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
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
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('MMM d, yyyy').format(_endDate),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
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
                    
                    // Net Profit Card (Hero)
                    Card(
                      color: netProfit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'Net Profit',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${netProfit.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: netProfit >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${profitMargin.toStringAsFixed(1)}% margin',
                                style: TextStyle(
                                  color: netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Income/Expense Summary Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard('Income', totalIncome, Colors.green),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard('Expenses', totalExpense, Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Income Breakdown
                    _buildSection('Income Breakdown', income, 'category', Colors.green),
                    const SizedBox(height: 24),
                    
                    // Expense Breakdown
                    _buildSection('Expense Breakdown', expenses, 'expenseGroup', Colors.red),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items, String labelKey, Color color) {
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('No data', style: TextStyle(color: Colors.grey.shade500))),
            ),
          ),
        ],
      );
    }

    // Calculate total for percentage
    double total = 0;
    for (var item in items) {
      total += (item['total'] as num?)?.toDouble() ?? 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: items.map((item) {
              final label = item[labelKey]?.toString() ?? 'Other';
              final amount = (item['total'] as num?)?.toDouble() ?? 0;
              final percentage = total > 0 ? (amount / total * 100) : 0;
              
              return ListTile(
                title: Text(label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
