import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/database_helper.dart';
import 'add_transaction_screen.dart';
import 'transaction_list_screen.dart';

class FinanceDashboard extends StatefulWidget {
  const FinanceDashboard({super.key});

  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard> {
  bool _isLoading = true;
  double _totalIncome = 0;
  double _totalExpense = 0;
  List<Map<String, dynamic>> _recentTransactions = [];

  final String _firmId = 'DEFAULT'; // TODO: Get from auth provider

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final summary = await DatabaseHelper().getFinanceSummary(
      _firmId, 
      startOfMonth.toIso8601String(), 
      endOfMonth.toIso8601String()
    );

    final recent = await DatabaseHelper().getTransactions(
      firmId: _firmId, 
      limit: 5
    );

    setState(() {
      _totalIncome = summary['income'] ?? 0;
      _totalExpense = summary['expense'] ?? 0;
      _recentTransactions = recent;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final netProfit = _totalIncome - _totalExpense;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Finance & Operations'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              _buildSummarySection(netProfit),
              const SizedBox(height: 24),
              
              // Quick Actions
              const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildQuickActions(),
              const SizedBox(height: 24),

              // Recent Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recent Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => const TransactionListScreen())
                    ).then((_) => _loadData()),
                    child: const Text("View All"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildRecentTransactionsList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen())
        ).then((_) => _loadData()),
        label: const Text('Add Transaction'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.black,
      ),
    );
  }

  Widget _buildSummarySection(double netProfit) {
    return Column(
      children: [
        // Net Profit Big Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: netProfit >= 0 
                ? [Colors.green.shade700, Colors.green.shade500]
                : [Colors.red.shade700, Colors.red.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (netProfit >= 0 ? Colors.green : Colors.red).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Net Profit (This Month)", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                "Rs. ${netProfit.abs().toStringAsFixed(0)}",
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  netProfit >= 0 ? "PROFITABLE" : "LOSS",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMiniCard(
                title: "Income", 
                amount: _totalIncome, 
                color: Colors.green, 
                icon: Icons.arrow_downward
              )
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMiniCard(
                title: "Expenses", 
                amount: _totalExpense, 
                color: Colors.red, 
                icon: Icons.arrow_upward
              )
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCard({required String title, required double amount, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Rs. ${amount.toStringAsFixed(0)}",
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionButton("Add Income", Icons.add_circle_outline, Colors.green, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen(type: 'INCOME'))
          ).then((_) => _loadData());
        }),
        _buildActionButton("Add Expense", Icons.remove_circle_outline, Colors.red, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen(type: 'EXPENSE'))
          ).then((_) => _loadData());
        }),
        _buildActionButton("Reports", Icons.bar_chart, Colors.purple, () {
          // TODO: Navigate to Reports Hub
        }),
        _buildActionButton("Payroll", Icons.people_outline, Colors.blue, () {
           // TODO: Navigate to Payroll
        }),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text("No transactions yet", style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return Column(
      children: _recentTransactions.map((t) {
        final isIncome = t['type'] == 'INCOME';
        final amount = (t['amount'] as num).toDouble();
        final date = DateTime.parse(t['date']);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            title: Text(t['category'] ?? 'Uncategorized', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('MMM d, yyyy').format(date)),
            trailing: Text(
              "${isIncome ? '+' : '-'} ₹${amount.toStringAsFixed(0)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isIncome ? Colors.green : Colors.red,
                fontSize: 16,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
