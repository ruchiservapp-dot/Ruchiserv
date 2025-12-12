import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../screens/add_transaction_screen.dart'; // Note: This might be finance/add_transaction_screen.dart if moved
import 'package:ruchiserv/l10n/app_localizations.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String _filterType = 'All'; // All, INCOME, EXPENSE

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper().getTransactions(
      type: _filterType == 'All' ? null : _filterType,
    );
    setState(() {
      _transactions = list;
      _isLoading = false;
    });
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
    );
    if (result == true) {
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.transactions),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) {
              setState(() => _filterType = val);
              _loadTransactions();
            },
            itemBuilder: (context) => [AppLocalizations.of(context)!.filterAll, 'INCOME', 'EXPENSE'] // Keep API values English for logic simplicity, translate UI
                .map((e) => PopupMenuItem(value: e, child: Text(e)))
                .toList(),
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTransaction,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noTransactionsFound))
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final t = _transactions[index];
                    final isIncome = t['type'] == 'INCOME';
                    return Dismissible(
                      key: Key(t['id'].toString()),
                      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(AppLocalizations.of(context)!.deleteTransactionTitle),
                            content: Text(AppLocalizations.of(context)!.deleteTransactionContent),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.cancel)),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppLocalizations.of(context)!.delete)),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) async {
                        await DatabaseHelper().deleteTransaction(t['id']);
                        _loadTransactions();
                      },
                      child: ListTile(
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
                          "${isIncome ? '+' : '-'} Rs. ${t['amount']}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isIncome ? Colors.green : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
// Removed TransactionForm class as we now use a dedicated screen.
