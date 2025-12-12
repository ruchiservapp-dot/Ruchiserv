import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/database_helper.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _filterType; // null for All, INCOME, EXPENSE

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper().getTransactions(
      firmId: 'DEFAULT', 
      type: _filterType,
      limit: 100
    );
    setState(() {
      _transactions = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (val) {
              setState(() => _filterType = val);
              _loadTransactions();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All')),
              const PopupMenuItem(value: 'INCOME', child: Text('Income')),
              const PopupMenuItem(value: 'EXPENSE', child: Text('Expense')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(child: Text("No transactions found"))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final t = _transactions[index];
                    final isIncome = t['type'] == 'INCOME';
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isIncome ? Colors.green : Colors.red,
                        ),
                        title: Text(t['category'] ?? 'Uncategorized'),
                        subtitle: Text("${DateFormat('MMM d').format(DateTime.parse(t['date']))} • ${t['mode'] ?? ''}"),
                        trailing: Text(
                          "${isIncome ? '+' : '-'} ₹${t['amount']}",
                          style: TextStyle(
                            color: isIncome ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onLongPress: () => _confirmDelete(t['id']),
                      ),
                    );
                  },
                ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Transaction?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().deleteTransaction(id);
              if (mounted) Navigator.pop(context);
              _loadTransactions();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }
}
