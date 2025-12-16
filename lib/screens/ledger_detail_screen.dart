import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import 'add_transaction_screen.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class LedgerDetailScreen extends StatefulWidget {
  final String entityName;
  final String entityType; // Supplier, Staff, Customer
  final int entityId;

  const LedgerDetailScreen({
    super.key,
    required this.entityName,
    required this.entityType,
    required this.entityId,
  });

  @override
  State<LedgerDetailScreen> createState() => _LedgerDetailScreenState();
}

class _LedgerDetailScreenState extends State<LedgerDetailScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  double _totalIncome = 0;
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper().getTransactions(
      relatedEntityType: widget.entityType.toUpperCase(),
      relatedEntityId: widget.entityId,
    );
    
    double income = 0;
    double expense = 0;
    
    for (var t in list) {
       if (t['type'] == 'INCOME') {
         income += (t['amount'] as num).toDouble();
       } else {
         expense += (t['amount'] as num).toDouble();
       }
    }

    setState(() {
      _transactions = list;
      _totalIncome = income;
      _totalExpense = expense;
      _isLoading = false;
    });
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          initialPartyType: widget.entityType,
          initialPartyName: widget.entityName,
          initialPartyId: widget.entityId,
        ),
      ),
    );
    if (result == true) {
      _loadLedger();
    }
  }

  @override
  Widget build(BuildContext context) {
    final netBalance = _totalIncome - _totalExpense;
    final isPositive = netBalance >= 0;

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.entityName} Ledger"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTransaction,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Summary Card
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.white,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem("Debit (-)", _totalExpense, Colors.red),
                      _buildSummaryItem("Credit (+)", _totalIncome, Colors.green),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       const Text("Net Balance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                       Text(
                         "₹ ${netBalance.abs().toStringAsFixed(2)} ${isPositive ? 'Cr' : 'Dr'}",
                         style: TextStyle(
                           fontSize: 20, 
                           fontWeight: FontWeight.bold,
                           color: isPositive ? Colors.green : Colors.red,
                         ),
                       ),
                    ],
                  )
                ],
              ),
            ),
          ),

          // Transaction List
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                  ? Center(child: Text(AppLocalizations.of(context)!.noTransactionsFound))
                  : ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final t = _transactions[index];
                        final isIncome = t['type'] == 'INCOME';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIncome ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(t['category'] ?? 'Uncategorized'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${t['date']} • ${t['paymentMode'] ?? (t['mode'] ?? 'Cash')}"),
                              if (t['description'] != null && t['description'].toString().isNotEmpty)
                                Text(t['description'], style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                          ),
                          trailing: Text(
                            "${isIncome ? '+' : '-'} ₹ ${t['amount']}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isIncome ? Colors.green : Colors.red,
                              fontSize: 16,
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

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          "₹ ${amount.toStringAsFixed(2)}",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
