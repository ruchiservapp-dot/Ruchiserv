// MODULE: SUPPLIER LEDGER SCREEN (v34)
// Features: Personal finance ledger with payments, balance, and export
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import 'report_preview_page.dart';

class SupplierLedgerScreen extends StatefulWidget {
  final int supplierId;
  final String supplierName;
  
  const SupplierLedgerScreen({super.key, required this.supplierId, required this.supplierName});

  @override
  State<SupplierLedgerScreen> createState() => _SupplierLedgerScreenState();
}

class _SupplierLedgerScreenState extends State<SupplierLedgerScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  
  List<Map<String, dynamic>> _transactions = [];
  double _totalInvoices = 0;
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
    
    // Get transactions for this supplier
    final transactions = await db.rawQuery('''
      SELECT f.*, 
             CASE WHEN f.type = 'EXPENSE' AND f.category = 'PURCHASE' THEN 'INVOICE' 
                  WHEN f.type = 'EXPENSE' THEN 'PAYMENT' 
                  ELSE 'OTHER' END as txnType
      FROM finance f
      WHERE (f.partyName LIKE ? OR f.referenceId LIKE ?) 
        AND f.date BETWEEN ? AND ?
      ORDER BY f.date DESC
    ''', ['%${widget.supplierName}%', '%SUPPLIER:${widget.supplierId}%', startStr, endStr]);
    
    // Also get PO summaries as invoices
    final poSummary = await db.rawQuery('''
      SELECT SUM(totalAmount) as totalInvoiced
      FROM purchase_orders 
      WHERE vendorId = ? AND DATE(createdAt) BETWEEN ? AND ?
    ''', [widget.supplierId, startStr, endStr]);
    
    double invoiced = (poSummary.first['totalInvoiced'] as num?)?.toDouble() ?? 0;
    double paid = 0;
    
    for (var t in transactions) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0;
      if (t['txnType'] == 'PAYMENT') {
        paid += amount;
      }
    }
    
    setState(() {
      _transactions = List<Map<String, dynamic>>.from(transactions);
      _totalInvoices = invoiced;
      _totalPaid = paid;
      _balance = invoiced - paid;
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
    final headers = ['Date', 'Description', 'Type', 'Amount'];
    final rows = _transactions.map((t) => [
      t['date'] ?? '',
      t['description'] ?? t['category'] ?? '',
      t['txnType'] ?? '',
      '₹${(t['amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
    ]).toList();
    
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReportPreviewPage(
        title: 'Supplier Ledger',
        subtitle: '${widget.supplierName} - ${DateFormat('MMM d').format(_startDate)} to ${DateFormat('MMM d').format(_endDate)}',
        headers: headers,
        rows: rows,
        accentColor: Colors.teal,
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
                  color: Colors.teal.shade50,
                  child: InkWell(
                    onTap: _pickDateRange,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Colors.teal.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.teal.shade700),
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
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _summaryItem('PO Value', _totalInvoices, Colors.indigo),
                              Container(width: 1, height: 40, color: Colors.grey.shade300),
                              _summaryItem('Paid', _totalPaid, Colors.green),
                              Container(width: 1, height: 40, color: Colors.grey.shade300),
                              _summaryItem('Balance', _balance, _balance > 0 ? Colors.orange : Colors.green),
                            ],
                          ),
                          if (_balance > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Pending payment: ₹${_balance.toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
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
    final txnType = txn['txnType'] ?? 'OTHER';
    final isPayment = txnType == 'PAYMENT';
    final amount = (txn['amount'] as num?)?.toDouble() ?? 0;
    
    Color color = Colors.grey;
    IconData icon = Icons.receipt;
    
    if (isPayment) {
      color = Colors.green;
      icon = Icons.payment;
    } else if (txnType == 'INVOICE') {
      color = Colors.indigo;
      icon = Icons.receipt_long;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(txn['description'] ?? txn['category'] ?? 'Transaction'),
        subtitle: Text('${txn['date']} • $txnType', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Text(
          '${isPayment ? '+' : ''}₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPayment ? Colors.green : color,
          ),
        ),
      ),
    );
  }
}
