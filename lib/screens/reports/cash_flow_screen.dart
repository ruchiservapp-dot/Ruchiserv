// MODULE: CASH FLOW STATEMENT SCREEN (Operating Cash Only)
// Shows cash movement for a period with opening/closing balance
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';
import '../report_preview_page.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key});

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  Map<String, dynamic>? _data;
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
    
    final data = await DatabaseHelper().getCashFlowData(_firmId, startStr, endStr);
    
    setState(() {
      _data = data;
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
    if (_data == null) return;
    
    final inflows = (_data!['inflows'] as List?) ?? [];
    final outflows = (_data!['outflows'] as List?) ?? [];
    
    final headers = ['Item', 'Amount (₹)'];
    final rows = <List<dynamic>>[
      ['Opening Cash Balance', _data!['openingBalance']],
      ['', ''],
      ['--- CASH INFLOWS ---', ''],
    ];
    
    for (var i in inflows) {
      rows.add([i['category'] ?? 'Other', i['total']]);
    }
    rows.add(['Total Cash In', _data!['totalInflow']]);
    
    rows.add(['', '']);
    rows.add(['--- CASH OUTFLOWS ---', '']);
    
    for (var o in outflows) {
      rows.add([o['expenseGroup'] ?? 'Other', o['total']]);
    }
    rows.add(['Total Cash Out', _data!['totalOutflow']]);
    
    rows.add(['', '']);
    rows.add(['NET CASH FLOW', _data!['netCashFlow']]);
    rows.add(['Closing Cash Balance', _data!['closingBalance']]);
    
    final startStr = DateFormat('MMM d').format(_startDate);
    final endStr = DateFormat('MMM d, yyyy').format(_endDate);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          title: 'Cash Flow Statement',
          subtitle: '$startStr to $endStr',
          headers: headers,
          rows: rows,
          accentColor: Colors.teal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openingBalance = (_data?['openingBalance'] as num?)?.toDouble() ?? 0;
    final totalInflow = (_data?['totalInflow'] as num?)?.toDouble() ?? 0;
    final totalOutflow = (_data?['totalOutflow'] as num?)?.toDouble() ?? 0;
    final netCashFlow = (_data?['netCashFlow'] as num?)?.toDouble() ?? 0;
    final closingBalance = (_data?['closingBalance'] as num?)?.toDouble() ?? 0;
    final inflows = (_data?['inflows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final outflows = (_data?['outflows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Flow'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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
                    
                    // Summary Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard('Opening', openingBalance, Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard('Net Flow', netCashFlow, netCashFlow >= 0 ? Colors.green : Colors.red),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard('Closing', closingBalance, Colors.teal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Cash Inflows Section
                    _buildSectionHeader('Cash Inflows', Icons.arrow_downward, Colors.green),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          if (inflows.isEmpty)
                            const ListTile(title: Text('No cash inflows', style: TextStyle(color: Colors.grey)))
                          else
                            ...inflows.map((i) => Column(
                              children: [
                                _buildFlowItem(i['category'] ?? 'Other', (i['total'] as num).toDouble(), Colors.green),
                                if (inflows.last != i) const Divider(height: 1),
                              ],
                            )),
                          const Divider(height: 1),
                          _buildTotalItem('Total Inflow', totalInflow, Colors.green),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Cash Outflows Section
                    _buildSectionHeader('Cash Outflows', Icons.arrow_upward, Colors.red),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          if (outflows.isEmpty)
                            const ListTile(title: Text('No cash outflows', style: TextStyle(color: Colors.grey)))
                          else
                            ...outflows.map((o) => Column(
                              children: [
                                _buildFlowItem(o['expenseGroup'] ?? 'Other', (o['total'] as num).toDouble(), Colors.red),
                                if (outflows.last != o) const Divider(height: 1),
                              ],
                            )),
                          const Divider(height: 1),
                          _buildTotalItem('Total Outflow', totalOutflow, Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFlowItem(String label, double amount, Color color) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(
        '₹${amount.toStringAsFixed(0)}',
        style: TextStyle(color: color),
      ),
    );
  }

  Widget _buildTotalItem(String label, double amount, Color color) {
    return Container(
      color: color.withOpacity(0.05),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
      ),
    );
  }
}
