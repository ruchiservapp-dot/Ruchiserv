// MODULE: SUBCONTRACTOR LEDGER SCREEN (v34)
// Features: Personal ledger, payments, balance, export
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import 'report_preview_page.dart';

class SubcontractorLedgerScreen extends StatefulWidget {
  final int subcontractorId;
  final String subcontractorName;
  
  const SubcontractorLedgerScreen({super.key, required this.subcontractorId, required this.subcontractorName});

  @override
  State<SubcontractorLedgerScreen> createState() => _SubcontractorLedgerScreenState();
}

class _SubcontractorLedgerScreenState extends State<SubcontractorLedgerScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  
  List<Map<String, dynamic>> _transactions = [];
  double _totalEarned = 0;
  double _totalPaid = 0;
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final db = await DatabaseHelper().database;
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    
    // Get transactions for this subcontractor
    final transactions = await db.rawQuery('''
      SELECT * FROM finance
      WHERE partyName LIKE ? AND date BETWEEN ? AND ?
      ORDER BY date DESC
    ''', ['%${widget.subcontractorName}%', startStr, endStr]);
    
    double earned = 0;
    double paid = 0;
    
    for (var t in transactions) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0;
      if (t['type'] == 'EXPENSE') {
        paid += amount;
      } else {
        earned += amount;
      }
    }
    
    setState(() {
      _transactions = List<Map<String, dynamic>>.from(transactions);
      _totalEarned = earned;
      _totalPaid = paid;
      _balance = earned - paid;
      _isLoading = false;
    });
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  void _exportReport() {
    final headers = ['Date', 'Description', 'Category', 'Type', 'Amount'];
    final rows = _transactions.map((t) => [
      t['date'] ?? '',
      t['description'] ?? '',
      t['category'] ?? '',
      t['type'] ?? '',
      '₹${(t['amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
    ]).toList();
    
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReportPreviewPage(
        title: 'Subcontractor Ledger',
        subtitle: '${widget.subcontractorName} - ${DateFormat('MMM d').format(_startDate)} to ${DateFormat('MMM d').format(_endDate)}',
        headers: headers,
        rows: rows,
        accentColor: Colors.purple,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ledger'),
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportReport, tooltip: 'Export'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date filter
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.purple.shade50,
                  child: InkWell(
                    onTap: _pickDateRange,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Colors.purple.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.purple.shade700),
                      ],
                    ),
                  ),
                ),
                
                // Summary Card
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _summaryItem('Earned', _totalEarned, Colors.green),
                          Container(width: 1, height: 40, color: Colors.grey.shade300),
                          _summaryItem('Paid', _totalPaid, Colors.blue),
                          Container(width: 1, height: 40, color: Colors.grey.shade300),
                          _summaryItem('Balance', _balance, _balance >= 0 ? Colors.orange : Colors.red),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Transactions list
                Expanded(
                  child: _transactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No transactions in this period'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _transactions.length,
                          itemBuilder: (ctx, i) => _buildTransactionTile(_transactions[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> txn) {
    final isExpense = txn['type'] == 'EXPENSE';
    final amount = (txn['amount'] as num?)?.toDouble() ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isExpense ? Colors.blue.shade100 : Colors.green.shade100,
          child: Icon(
            isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            color: isExpense ? Colors.blue : Colors.green,
            size: 20,
          ),
        ),
        title: Text(txn['description'] ?? txn['category'] ?? 'Transaction'),
        subtitle: Text(txn['date'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Text(
          '${isExpense ? '-' : '+'}₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isExpense ? Colors.blue : Colors.green,
          ),
        ),
      ),
    );
  }
}
