import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '5.2_transactions_screen.dart';
import '5.3_ledger_screen.dart';
import '5.4_invoices_screen.dart';
import 'report_preview_page.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalAR = 0; // Accounts Receivable
  double _totalAP = 0; // Accounts Payable
  List<Map<String, dynamic>> _recentTransactions = [];
  bool _isLoading = true;
  String _firmId = 'DEFAULT';

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
           // If start date is after end date, move end date to start date
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          // If end date is before start date, move start date to end date
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
      _loadData();
    }
  }


  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Load firm ID
    final prefs = await SharedPreferences.getInstance();
    _firmId = prefs.getString('last_firm') ?? 'DEFAULT';
    
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    final summary = await DatabaseHelper().getFinanceSummary(_firmId, startStr, endStr);
    final recent = await DatabaseHelper().getTransactions(limit: 5);
    
    // Load AR/AP totals
    final arTotal = await DatabaseHelper().getTotalAR(_firmId);
    final apTotal = await DatabaseHelper().getTotalAP(_firmId);

    setState(() {
      _totalIncome = summary['income'] ?? 0;
      _totalExpense = summary['expense'] ?? 0;
      _totalAR = arTotal;
      _totalAP = apTotal;
      _recentTransactions = recent;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final netBalance = _totalIncome - _totalExpense;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Filter
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(true),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text("From", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM d, yyyy').format(_startDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.shade300),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(false),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.event, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text("To", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM d, yyyy').format(_endDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      AppLocalizations.of(context)!.income,
                      _totalIncome,
                      Colors.green,
                      Icons.arrow_downward,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      AppLocalizations.of(context)!.expense,
                      _totalExpense,
                      Colors.red,
                      Icons.arrow_upward,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Net Balance
              Card(
                color: netBalance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                child: ListTile(
                  title: Text(AppLocalizations.of(context)!.netBalance, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(
                    "Rs. ${netBalance.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: netBalance >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // AR/AP Summary Cards
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.arrow_downward, color: Colors.blue.shade700, size: 18),
                                const SizedBox(width: 4),
                                Text('Receivables', style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "₹${_totalAR.toStringAsFixed(0)}",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                            ),
                            Text('Outstanding AR', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.arrow_upward, color: Colors.orange.shade700, size: 18),
                                const SizedBox(width: 4),
                                Text('Payables', style: TextStyle(color: Colors.orange.shade700, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "₹${_totalAP.toStringAsFixed(0)}",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                            ),
                            Text('Outstanding AP', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Actions - Now 4 buttons in 2 rows
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    'Invoices',
                    Icons.receipt_long,
                    Colors.indigo,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InvoicesScreen()),
                    ).then((_) => _loadData()),
                  ),
                  _buildActionButton(
                    AppLocalizations.of(context)!.transactions,
                    Icons.list_alt,
                    Colors.blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                    ).then((_) => _loadData()),
                  ),
                  _buildActionButton(
                    AppLocalizations.of(context)!.ledgers,
                    Icons.book,
                    Colors.purple,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LedgerScreen()),
                    ),
                  ),
                  _buildActionButton(
                    AppLocalizations.of(context)!.export,
                    Icons.file_download,
                    Colors.teal,
                    () async {
                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const Center(child: CircularProgressIndicator()),
                      );

                      try {
                        final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
                        final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

                        final transactions = await DatabaseHelper().getTransactions(
                          startDate: startStr,
                          endDate: endStr,
                        );

                        if (!context.mounted) return;
                        Navigator.pop(context); // Close loading

                        if (transactions.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.noTransactionsFound)),
                          );
                          return;
                        }

                        final headers = ['Date', 'Type', 'Category', 'Mode', 'Description', 'Amount'];
                        final rows = transactions.map((t) => [
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
                              title: 'Finance Report',
                              subtitle: '$startStr to $endStr',
                              headers: headers,
                              rows: rows,
                              accentColor: Colors.teal,
                            ),
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // Close loading if error
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error generating report: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Transactions
              Text(AppLocalizations.of(context)!.recentTransactions, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recentTransactions.isEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(AppLocalizations.of(context)!.noTransactionsFound)))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentTransactions.length,
                          itemBuilder: (context, index) {
                            final t = _recentTransactions[index];
                            final isIncome = t['type'] == 'INCOME';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                                  child: Icon(
                                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isIncome ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(t['category'] ?? 'Uncategorized'),
                                subtitle: Text(t['date']),
                                trailing: Text(
                                  "${isIncome ? '+' : '-'} Rs. ${t['amount']}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isIncome ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Rs. ${amount.toStringAsFixed(0)}",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
