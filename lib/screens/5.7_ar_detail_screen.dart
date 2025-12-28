// MODULE: ACCOUNTS RECEIVABLE DETAIL SCREEN
// Last Updated: 2025-12-17 | Features: Customer aging breakdown, outstanding balances
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

class ARDetailScreen extends StatefulWidget {
  const ARDetailScreen({super.key});

  @override
  State<ARDetailScreen> createState() => _ARDetailScreenState();
}

class _ARDetailScreenState extends State<ARDetailScreen> {
  Map<String, dynamic>? _agingData;
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
    
    final aging = await DatabaseHelper().getARAgingReport(_firmId);
    
    setState(() {
      _agingData = aging;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _agingData?['summary'] as Map<String, dynamic>? ?? {};
    final customers = (_agingData?['customers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    final current = (summary['current'] as num?)?.toDouble() ?? 0;
    final days30 = (summary['days30'] as num?)?.toDouble() ?? 0;
    final days60 = (summary['days60'] as num?)?.toDouble() ?? 0;
    final days90Plus = (summary['days90Plus'] as num?)?.toDouble() ?? 0;
    final total = current + days30 + days60 + days90Plus;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts Receivable'),
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
                    // Total Outstanding
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, size: 40, color: Colors.blue.shade700),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Outstanding', style: TextStyle(color: Colors.grey.shade700)),
                                Text(
                                  '₹${total.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Aging Buckets
                    const Text('Aging Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildAgingCard('Current', current, Colors.green)),
                        Expanded(child: _buildAgingCard('30 Days', days30, Colors.yellow.shade700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildAgingCard('60 Days', days60, Colors.orange)),
                        Expanded(child: _buildAgingCard('90+ Days', days90Plus, Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Customer List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('By Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${customers.length} customers', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (customers.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle, size: 48, color: Colors.green.shade400),
                                const SizedBox(height: 8),
                                const Text('No outstanding receivables!'),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...customers.map((customer) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              (customer['customerName']?.toString() ?? 'C')[0].toUpperCase(),
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                          title: Text(customer['customerName']?.toString() ?? 'Customer'),
                          subtitle: customer['oldestDue'] != null 
                              ? Text('Oldest due: ${customer['oldestDue']}', style: const TextStyle(fontSize: 12))
                              : null,
                          trailing: Text(
                            '₹${((customer['outstanding'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700, fontSize: 16),
                          ),
                        ),
                      )),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAgingCard(String label, double amount, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
