// MODULE: SUPPLIER HOME SCREEN (v34)
// Features: Dashboard with PO notifications, calendar, ledger access
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '9.1_supplier_calendar_screen.dart';
import '9.2_supplier_po_screen.dart';
import '9.3_supplier_ledger_screen.dart';

class SupplierHomeScreen extends StatefulWidget {
  const SupplierHomeScreen({super.key});

  @override
  State<SupplierHomeScreen> createState() => _SupplierHomeScreenState();
}

class _SupplierHomeScreenState extends State<SupplierHomeScreen> {
  bool _isLoading = true;
  int _supplierId = 0;
  String _supplierName = '';
  
  int _newPOs = 0;
  int _pendingDeliveries = 0;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _recentPOs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final sp = await SharedPreferences.getInstance();
    final mobile = sp.getString('last_mobile') ?? '';
    final firmId = sp.getString('last_firm') ?? '';
    
    final db = await DatabaseHelper().database;
    
    // Get supplier by mobile
    final suppliers = await db.rawQuery('''
      SELECT * FROM suppliers WHERE mobile = ?
    ''', [mobile]);
    
    if (suppliers.isNotEmpty) {
      _supplierId = suppliers.first['id'] as int? ?? 0;
      _supplierName = suppliers.first['name']?.toString() ?? 'Supplier';
    }
    
    if (_supplierId > 0) {
      // Get PO stats
      final newPOs = await db.rawQuery('''
        SELECT COUNT(*) as count FROM purchase_orders 
        WHERE vendorId = ? AND status = 'SENT'
      ''', [_supplierId]);
      _newPOs = (newPOs.first['count'] as num?)?.toInt() ?? 0;
      
      final pendingDeliveries = await db.rawQuery('''
        SELECT COUNT(*) as count FROM purchase_orders 
        WHERE vendorId = ? AND status IN ('ACCEPTED', 'DISPATCHED')
      ''', [_supplierId]);
      _pendingDeliveries = (pendingDeliveries.first['count'] as num?)?.toInt() ?? 0;
      
      // Monthly summary
      final monthStart = DateFormat('yyyy-MM-01').format(DateTime.now());
      final summary = await db.rawQuery('''
        SELECT COUNT(*) as totalPOs, COALESCE(SUM(totalAmount), 0) as totalAmount
        FROM purchase_orders WHERE vendorId = ? AND createdAt >= ?
      ''', [_supplierId, monthStart]);
      _summary = summary.isNotEmpty ? Map<String, dynamic>.from(summary.first) : {};
      
      // Recent POs
      final recent = await db.rawQuery('''
        SELECT * FROM purchase_orders 
        WHERE vendorId = ? 
        ORDER BY createdAt DESC LIMIT 5
      ''', [_supplierId]);
      _recentPOs = List<Map<String, dynamic>>.from(recent);
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
              _buildWelcomeCard(),
              const SizedBox(height: 16),
              _buildNotificationCards(),
              const SizedBox(height: 16),
              _buildQuickActions(),
              const SizedBox(height: 16),
              _buildRecentPOs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final totalPOs = (_summary['totalPOs'] as num?)?.toInt() ?? 0;
    final totalAmount = (_summary['totalAmount'] as num?)?.toDouble() ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(Icons.storefront, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome,', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                    Text(_supplierName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('$totalPOs', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('POs This Month', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('₹${(totalAmount / 1000).toStringAsFixed(1)}K', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('Total Value', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCards() {
    return Row(
      children: [
        Expanded(
          child: _notificationCard('New POs', _newPOs, Colors.orange, Icons.notification_important, () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SupplierPoScreen(supplierId: _supplierId, supplierName: _supplierName),
            )).then((_) => _loadData());
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _notificationCard('Pending', _pendingDeliveries, Colors.blue, Icons.local_shipping, () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SupplierPoScreen(supplierId: _supplierId, supplierName: _supplierName),
            )).then((_) => _loadData());
          }),
        ),
      ],
    );
  }

  Widget _notificationCard(String label, int count, Color color, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                    Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  ],
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(child: _actionCard('POs', Icons.receipt_long, Colors.indigo, () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SupplierPoScreen(supplierId: _supplierId, supplierName: _supplierName),
          )).then((_) => _loadData());
        })),
        const SizedBox(width: 8),
        Expanded(child: _actionCard('Calendar', Icons.calendar_month, Colors.blue, () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SupplierCalendarScreen(supplierId: _supplierId),
          ));
        })),
        const SizedBox(width: 8),
        Expanded(child: _actionCard('Ledger', Icons.account_balance_wallet, Colors.green, () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SupplierLedgerScreen(supplierId: _supplierId, supplierName: _supplierName),
          ));
        })),
      ],
    );
  }

  Widget _actionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPOs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Purchase Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton(onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => SupplierPoScreen(supplierId: _supplierId, supplierName: _supplierName),
              )).then((_) => _loadData());
            }, child: const Text('View All')),
          ],
        ),
        if (_recentPOs.isEmpty)
          Card(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('No purchase orders yet', style: TextStyle(color: Colors.grey.shade600))),
          ))
        else
          ...List.generate(_recentPOs.length, (i) => _buildPoTile(_recentPOs[i])),
      ],
    );
  }

  Widget _buildPoTile(Map<String, dynamic> po) {
    final status = po['status'] ?? 'SENT';
    Color statusColor = Colors.orange;
    if (status == 'ACCEPTED') statusColor = Colors.blue;
    else if (status == 'DISPATCHED') statusColor = Colors.purple;
    else if (status == 'DELIVERED') statusColor = Colors.green;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.receipt, color: statusColor),
        ),
        title: Text(po['poNumber'] ?? 'PO', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('₹${(po['totalAmount'] as num?)?.toStringAsFixed(0) ?? '0'} • ${po['createdAt']?.toString().substring(0, 10) ?? ''}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
