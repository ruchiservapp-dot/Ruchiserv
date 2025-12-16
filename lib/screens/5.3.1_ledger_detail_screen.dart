import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import 'report_preview_page.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class LedgerDetailScreen extends StatefulWidget {
  final String entityType; // SUPPLIER, STAFF, CUSTOMER, SUBCONTRACTOR
  final int entityId;
  final String entityName;
  final String? entityMobile;

  const LedgerDetailScreen({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    this.entityMobile,
  });

  @override
  State<LedgerDetailScreen> createState() => _LedgerDetailScreenState();
}

class _LedgerDetailScreenState extends State<LedgerDetailScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    try {
      // For CUSTOMER, we might need special handling if ID is 0/dummy
      // But assuming core entities have valid IDs.
      // Note: currently getTransactions filters by relatedEntityId (int)
      
      final list = await DatabaseHelper().getTransactions(
        startDate: startStr,
        endDate: endStr,
        relatedEntityType: widget.entityType,
        relatedEntityId: widget.entityId,
      );

      setState(() {
        _transactions = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading ledger: $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _openExportPreview() {
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    
    final headers = ['Date', 'Type', 'Category', 'Mode', 'Description', 'Amount'];
    final rows = _transactions.map((t) => [
      t['date'],
      t['type'],
      t['category'] ?? '-',
      t['mode'] ?? '-',
      t['description'] ?? '-',
      t['amount']
    ]).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          title: '${widget.entityName} - Ledger',
          subtitle: '$startStr to $endStr',
          headers: headers,
          rows: rows,
          accentColor: Colors.purple,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate Balance
    double totalCredit = 0; // Income/Recieved
    double totalDebit = 0; // Expense/Paid
    
    // In Ledger context:
    // If I am looking at a Supplier Ledger:
    // - Expense (Payment to Supplier) -> Debit? or Credit? 
    // Usually: Credit = Payable increased (Purchase), Debit = Payable decreased (Payment).
    // But typically apps store 'INCOME' (Money IN) and 'EXPENSE' (Money OUT) from current firm perspective.
    // So for Supplier:
    // - EXPENSE transaction = Payment made to Supplier.
    // - INCOME transaction = Refund from Supplier?
    
    // Let's stick to simple In/Out for now based on transaction type.
    
    for (var t in _transactions) {
      if (t['type'] == 'INCOME') {
        totalCredit += (t['amount'] as num).toDouble();
      } else {
        totalDebit += (t['amount'] as num).toDouble();
      }
    }
    
    double netBalance = totalCredit - totalDebit;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.entityName, style: const TextStyle(fontSize: 16)),
            if (widget.entityMobile != null)
              Text(widget.entityMobile!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _openExportPreview,
            tooltip: AppLocalizations.of(context)!.export,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Filter & Summary
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.purple.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                          );
                          if (picked != null) {
                            setState(() {
                              _startDate = picked.start;
                              _endDate = picked.end;
                            });
                            _loadData();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.purple),
                              const SizedBox(width: 8),
                              Text(
                                "${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Total Paid', totalDebit, Colors.red),
                    _buildSummaryItem('Total Recieved', totalCredit, Colors.green),
                    _buildSummaryItem('Net', netBalance, netBalance >= 0 ? Colors.green : Colors.red),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? Center(
                        child: Text(
                          "No transactions found for this period",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final t = _transactions[index];
                          final isIncome = t['type'] == 'INCOME';
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                                child: Icon(
                                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isIncome ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                              ),
                              title: Text(t['category'] ?? 'Transaction'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateFormat('MMM d, yyyy').format(DateTime.parse(t['date']))),
                                  if (t['description'] != null && t['description'].toString().isNotEmpty)
                                    Text(t['description'], maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                              trailing: Text(
                                "₹${t['amount']}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isIncome ? Colors.green : Colors.red,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double val, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          "₹${val.abs().toStringAsFixed(0)}",
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
