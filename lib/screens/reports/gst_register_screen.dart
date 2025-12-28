// MODULE: GST REGISTER SCREEN
// Last Updated: 2025-12-17 | Features: GST Input/Output tracking for GSTR-1 filing
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';
import '../report_preview_page.dart';

class GstRegisterScreen extends StatefulWidget {
  const GstRegisterScreen({super.key});

  @override
  State<GstRegisterScreen> createState() => _GstRegisterScreenState();
}

class _GstRegisterScreenState extends State<GstRegisterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _outputInvoices = [];
  List<Map<String, dynamic>> _inputTransactions = [];
  bool _isLoading = true;
  String _firmId = 'DEFAULT';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    _firmId = prefs.getString('last_firm') ?? 'DEFAULT';
    
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    
    // Output tax: From sales invoices
    final invoices = await DatabaseHelper().getInvoices(
      _firmId,
      startDate: startStr,
      endDate: endStr,
    );
    
    // Input tax: From expense transactions (purchases)
    final expenses = await DatabaseHelper().getTransactions(
      firmId: _firmId,
      startDate: startStr,
      endDate: endStr,
      type: 'EXPENSE',
    );
    
    setState(() {
      _outputInvoices = invoices;
      _inputTransactions = expenses;
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

  // Calculate totals
  Map<String, double> get _outputTotals {
    double taxable = 0, cgst = 0, sgst = 0, igst = 0;
    for (var inv in _outputInvoices) {
      taxable += (inv['subtotal'] as num?)?.toDouble() ?? 0;
      cgst += (inv['cgst'] as num?)?.toDouble() ?? 0;
      sgst += (inv['sgst'] as num?)?.toDouble() ?? 0;
      igst += (inv['igst'] as num?)?.toDouble() ?? 0;
    }
    return {'taxable': taxable, 'cgst': cgst, 'sgst': sgst, 'igst': igst, 'total': cgst + sgst + igst};
  }

  Map<String, double> get _inputTotals {
    // Estimate input tax at 5% (standard for purchases)
    double total = 0;
    for (var txn in _inputTransactions) {
      if (txn['category'] == 'Purchase' || txn['category'] == 'Raw Materials') {
        total += (txn['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    final estimatedTax = total * 0.05 / 1.05; // Reverse calculation from inclusive amount
    return {'taxable': total - estimatedTax, 'tax': estimatedTax};
  }

  void _exportGSTR1() {
    final headers = ['Invoice No', 'Date', 'Customer', 'GSTIN', 'Taxable', 'CGST', 'SGST', 'IGST', 'Total'];
    final rows = _outputInvoices.map((inv) => [
      inv['invoiceNumber'] ?? '',
      inv['invoiceDate'] ?? '',
      inv['customerName'] ?? '',
      inv['customerGstin'] ?? 'N/A',
      inv['subtotal'] ?? 0,
      inv['cgst'] ?? 0,
      inv['sgst'] ?? 0,
      inv['igst'] ?? 0,
      inv['totalAmount'] ?? 0,
    ]).toList();
    
    // Add totals row
    final totals = _outputTotals;
    rows.add(['TOTAL', '', '', '', totals['taxable'], totals['cgst'], totals['sgst'], totals['igst'], totals['taxable']! + totals['total']!]);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          title: 'GSTR-1 Summary',
          subtitle: '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
          headers: headers,
          rows: rows,
          accentColor: Colors.teal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outputTotals = _outputTotals;
    final inputTotals = _inputTotals;
    final netPayable = outputTotals['total']! - inputTotals['tax']!;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Register'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportGSTR1,
            tooltip: 'Export GSTR-1',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Output Tax'),
            Tab(text: 'Input Tax'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date Picker & Summary
                Container(
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Date Range
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate(true),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16),
                                  const SizedBox(width: 8),
                                  Text(DateFormat('MMM d').format(_startDate)),
                                  const Text(' - '),
                                  Text(DateFormat('MMM d, yyyy').format(_endDate)),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _pickDate(false),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // GST Summary
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryChip('Output', outputTotals['total']!, Colors.red),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryChip('Input', inputTotals['tax']!, Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryChip(
                              netPayable >= 0 ? 'Payable' : 'Credit',
                              netPayable.abs(),
                              netPayable >= 0 ? Colors.orange : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOutputTab(),
                      _buildInputTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputTab() {
    if (_outputInvoices.isEmpty) {
      return Center(child: Text('No invoices in selected period', style: TextStyle(color: Colors.grey.shade600)));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _outputInvoices.length,
      itemBuilder: (context, index) {
        final inv = _outputInvoices[index];
        final cgst = (inv['cgst'] as num?)?.toDouble() ?? 0;
        final sgst = (inv['sgst'] as num?)?.toDouble() ?? 0;
        final igst = (inv['igst'] as num?)?.toDouble() ?? 0;
        final totalTax = cgst + sgst + igst;
        
        return Card(
          child: ListTile(
            title: Text(inv['invoiceNumber'] ?? 'Invoice'),
            subtitle: Text('${inv['customerName']} | ${inv['invoiceDate']}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${(inv['subtotal'] as num?)?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontSize: 12)),
                Text(
                  '+₹${totalTax.toStringAsFixed(0)} GST',
                  style: TextStyle(color: Colors.red.shade600, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputTab() {
    final filtered = _inputTransactions.where((t) => 
      t['category'] == 'Purchase' || t['category'] == 'Raw Materials'
    ).toList();
    
    if (filtered.isEmpty) {
      return Center(child: Text('No purchase transactions in selected period', style: TextStyle(color: Colors.grey.shade600)));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final txn = filtered[index];
        final amount = (txn['amount'] as num?)?.toDouble() ?? 0;
        final estimatedTax = amount * 0.05 / 1.05;
        
        return Card(
          child: ListTile(
            title: Text(txn['partyName'] ?? txn['description'] ?? 'Purchase'),
            subtitle: Text('${txn['category']} | ${txn['date']}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                Text(
                  '~₹${estimatedTax.toStringAsFixed(0)} ITC',
                  style: TextStyle(color: Colors.green.shade600, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
