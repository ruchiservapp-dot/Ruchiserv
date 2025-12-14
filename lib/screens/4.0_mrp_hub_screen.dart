// MODULE: MRP HUB SCREEN
// 4 Submodules: MRP Run, MRP Output, Allotment, Purchase Orders
import 'package:flutter/material.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '4.3_mrp_run_screen.dart';
import '4.4_mrp_output_screen.dart';
import '4.5_allotment_screen.dart';
import '4.8_purchase_orders_screen.dart';
import '../db/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MrpHubScreen extends StatefulWidget {
  const MrpHubScreen({super.key});

  @override
  State<MrpHubScreen> createState() => _MrpHubScreenState();
}

class _MrpHubScreenState extends State<MrpHubScreen> {
  String? _firmId;
  int _pendingRuns = 0;
  int _completedRuns = 0;
  int _pendingPOs = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final sp = await SharedPreferences.getInstance();
    _firmId = sp.getString('last_firm');
    
    if (_firmId != null) {
      final db = await DatabaseHelper().database;
      
      // Count MRP runs
      final runs = await db.query('mrp_runs', where: 'firmId = ?', whereArgs: [_firmId]);
      final pending = runs.where((r) => r['status'] == 'DRAFT').length;
      final completed = runs.where((r) => r['status'] != 'DRAFT').length;
      
      // Count POs
      final pos = await db.query('purchase_orders', where: 'firmId = ?', whereArgs: [_firmId]);
      final pendingPos = pos.where((p) => p['status'] == 'SENT').length;
      
      setState(() {
        _pendingRuns = pending;
        _completedRuns = completed;
        _pendingPOs = pendingPos;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MRP Planning', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('Pending\nRuns', _pendingRuns, Colors.orange),
                  Container(width: 1, height: 40, color: Colors.white30),
                  _statItem('Completed\nRuns', _completedRuns, Colors.green),
                  Container(width: 1, height: 40, color: Colors.white30),
                  _statItem('Pending\nPOs', _pendingPOs, Colors.purple),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Text('MRP Submodules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            
            // Module 1: MRP Run
            _moduleCard(
              icon: Icons.play_circle_outline,
              title: 'MRP Run',
              subtitle: 'Select date & orders, calculate requirements',
              color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const MrpRunScreen(),
              )).then((_) => _loadStats()),
            ),
            
            // Module 2: MRP Output
            _moduleCard(
              icon: Icons.list_alt,
              title: 'MRP Output',
              subtitle: 'View ingredient requirements by run',
              color: Colors.teal,
              onTap: () => _showMrpOutputSelector(),
            ),
            
            // Module 3: Allotment
            _moduleCard(
              icon: Icons.assignment_ind,
              title: 'Allotment',
              subtitle: 'Assign ingredients to suppliers',
              color: Colors.orange,
              onTap: () => _showAllotmentSelector(),
            ),
            
            // Module 4: Purchase Orders
            _moduleCard(
              icon: Icons.receipt_long,
              title: 'Purchase Orders',
              subtitle: 'View and manage POs',
              color: Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const PurchaseOrdersScreen(),
              )).then((_) => _loadStats()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Widget _moduleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMrpOutputSelector() async {
    final db = await DatabaseHelper().database;
    final runs = await db.query('mrp_runs', 
      where: 'firmId = ?', 
      whereArgs: [_firmId],
      orderBy: 'createdAt DESC',
      limit: 20,
    );
    
    if (runs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No MRP runs found. Create one first.'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select MRP Run', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: runs.length,
                itemBuilder: (context, index) {
                  final run = runs[index];
                  return ListTile(
                    leading: Icon(Icons.analytics, color: run['status'] == 'DRAFT' ? Colors.orange : Colors.green),
                    title: Text('${run['runName'] ?? 'Run #${run['id']}'} - ${run['targetDate']}'),
                    subtitle: Text('${run['totalOrders']} orders | ${run['status']}'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MrpOutputScreen(mrpRunId: run['id'] as int, firmId: _firmId!),
                      ));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAllotmentSelector() async {
    final db = await DatabaseHelper().database;
    final runs = await db.query('mrp_runs', 
      where: "firmId = ? AND status IN ('DRAFT', 'MRP_DONE')", 
      whereArgs: [_firmId],
      orderBy: 'createdAt DESC',
      limit: 20,
    );
    
    if (runs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No MRP runs ready for allotment.'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select MRP Run for Allotment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: runs.length,
                itemBuilder: (context, index) {
                  final run = runs[index];
                  return ListTile(
                    leading: const Icon(Icons.assignment, color: Colors.orange),
                    title: Text('${run['runName'] ?? 'Run #${run['id']}'} - ${run['targetDate']}'),
                    subtitle: Text('${run['totalOrders']} orders'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AllotmentScreen(mrpRunId: run['id'] as int, firmId: _firmId!),
                      )).then((_) => _loadStats());
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
