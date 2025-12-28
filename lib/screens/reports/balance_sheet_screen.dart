// MODULE: BALANCE SHEET REPORT SCREEN (Simplified)
// Assets: Cash, AR, Inventory | Liabilities: AP, GST Payable
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';
import '../report_preview_page.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  DateTime _asOfDate = DateTime.now();
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
    
    final dateStr = DateFormat('yyyy-MM-dd').format(_asOfDate);
    final data = await DatabaseHelper().getBalanceSheetData(_firmId, dateStr);
    
    setState(() {
      _data = data;
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOfDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() => _asOfDate = picked);
      _loadData();
    }
  }

  void _exportReport() {
    if (_data == null) return;
    
    final assets = _data!['assets'] as Map<String, dynamic>;
    final liabilities = _data!['liabilities'] as Map<String, dynamic>;
    
    final headers = ['Item', 'Amount (₹)'];
    final rows = <List<dynamic>>[
      ['--- ASSETS ---', ''],
      ['Cash & Bank', assets['cash']],
      ['Accounts Receivable', assets['accountsReceivable']],
      ['Inventory', assets['inventory']],
      ['Total Assets', assets['total']],
      ['', ''],
      ['--- LIABILITIES ---', ''],
      ['Accounts Payable', liabilities['accountsPayable']],
      ['GST Payable', liabilities['gstPayable']],
      ['Total Liabilities', liabilities['total']],
      ['', ''],
      ['NET WORTH', _data!['netWorth']],
    ];
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          title: 'Balance Sheet',
          subtitle: 'As of ${DateFormat('MMM d, yyyy').format(_asOfDate)}',
          headers: headers,
          rows: rows,
          accentColor: Colors.indigo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assets = (_data?['assets'] as Map<String, dynamic>?) ?? {};
    final liabilities = (_data?['liabilities'] as Map<String, dynamic>?) ?? {};
    final netWorth = (_data?['netWorth'] as num?)?.toDouble() ?? 0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance Sheet'),
        backgroundColor: Colors.indigo,
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
                    // Date Picker
                    Card(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.indigo.shade700),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('As of Date', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  Text(
                                    DateFormat('MMMM d, yyyy').format(_asOfDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Icon(Icons.edit, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Net Worth Hero Card
                    Card(
                      color: netWorth >= 0 ? Colors.indigo.shade50 : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'Net Worth',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${netWorth.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: netWorth >= 0 ? Colors.indigo.shade700 : Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Assets - Liabilities',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Assets Section
                    _buildSectionHeader('Assets', Icons.account_balance_wallet, Colors.green),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          _buildLineItem('Cash & Bank', assets['cash'] ?? 0, Colors.green),
                          const Divider(height: 1),
                          _buildLineItem('Accounts Receivable (AR)', assets['accountsReceivable'] ?? 0, Colors.blue),
                          const Divider(height: 1),
                          _buildLineItem('Inventory', assets['inventory'] ?? 0, Colors.orange),
                          const Divider(height: 1),
                          _buildTotalItem('Total Assets', assets['total'] ?? 0, Colors.green),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Liabilities Section
                    _buildSectionHeader('Liabilities', Icons.credit_card, Colors.red),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          _buildLineItem('Accounts Payable (AP)', liabilities['accountsPayable'] ?? 0, Colors.red),
                          const Divider(height: 1),
                          _buildLineItem('GST Payable', liabilities['gstPayable'] ?? 0, Colors.orange),
                          const Divider(height: 1),
                          _buildTotalItem('Total Liabilities', liabilities['total'] ?? 0, Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
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

  Widget _buildLineItem(String label, num amount, Color color) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        '₹${amount.toStringAsFixed(0)}',
        style: TextStyle(fontWeight: FontWeight.w500, color: color),
      ),
    );
  }

  Widget _buildTotalItem(String label, num amount, Color color) {
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
