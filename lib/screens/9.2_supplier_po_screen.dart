// MODULE: SUPPLIER PO SCREEN (v34)
// Features: View POs, accept/reject, mark as dispatched, filter by status
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class SupplierPoScreen extends StatefulWidget {
  final int supplierId;
  final String supplierName;
  
  const SupplierPoScreen({super.key, required this.supplierId, required this.supplierName});

  @override
  State<SupplierPoScreen> createState() => _SupplierPoScreenState();
}

class _SupplierPoScreenState extends State<SupplierPoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _newPOs = [];
  List<Map<String, dynamic>> _acceptedPOs = [];
  List<Map<String, dynamic>> _deliveredPOs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPOs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPOs() async {
    setState(() => _isLoading = true);
    
    final db = await DatabaseHelper().database;
    
    final newPOs = await db.rawQuery('''
      SELECT * FROM purchase_orders WHERE vendorId = ? AND status = 'SENT' ORDER BY createdAt DESC
    ''', [widget.supplierId]);
    
    final acceptedPOs = await db.rawQuery('''
      SELECT * FROM purchase_orders WHERE vendorId = ? AND status IN ('ACCEPTED', 'DISPATCHED') ORDER BY acceptedAt DESC
    ''', [widget.supplierId]);
    
    final deliveredPOs = await db.rawQuery('''
      SELECT * FROM purchase_orders WHERE vendorId = ? AND status = 'DELIVERED' ORDER BY deliveredAt DESC LIMIT 50
    ''', [widget.supplierId]);
    
    setState(() {
      _newPOs = List<Map<String, dynamic>>.from(newPOs);
      _acceptedPOs = List<Map<String, dynamic>>.from(acceptedPOs);
      _deliveredPOs = List<Map<String, dynamic>>.from(deliveredPOs);
      _isLoading = false;
    });
  }

  Future<void> _acceptPO(Map<String, dynamic> po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept PO?'),
        content: Text('Accept ${po['poNumber']} for ₹${(po['totalAmount'] as num?)?.toStringAsFixed(0) ?? '0'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final db = await DatabaseHelper().database;
      await db.update('purchase_orders', {
        'status': 'ACCEPTED',
        'acceptedAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [po['id']]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PO Accepted!'), backgroundColor: Colors.green),
      );
      _loadPOs();
    }
  }

  Future<void> _markDispatched(Map<String, dynamic> po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Dispatched?'),
        content: Text('Confirm dispatch for ${po['poNumber']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Dispatched'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final db = await DatabaseHelper().database;
      await db.update('purchase_orders', {
        'status': 'DISPATCHED',
        'dispatchedAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [po['id']]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as Dispatched'), backgroundColor: Colors.blue),
      );
      _loadPOs();
    }
  }

  void _showPoDetails(Map<String, dynamic> po) async {
    final db = await DatabaseHelper().database;
    final items = await db.query('po_items', where: 'poId = ?', whereArgs: [po['id']]);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(po['poNumber'] ?? 'PO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Status: ${po['status']} • Created: ${po['createdAt']?.toString().substring(0, 10) ?? ''}'),
              const Divider(height: 24),
              Text('Items (${items.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade100,
                        radius: 16,
                        child: Text('${i + 1}', style: TextStyle(fontSize: 12, color: Colors.teal.shade800)),
                      ),
                      title: Text(item['itemName']?.toString() ?? 'Item'),
                      subtitle: Text('${item['quantity']} ${item['unit']} @ ₹${item['pricePerUnit']}'),
                      trailing: Text('₹${(item['totalPrice'] as num?)?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('₹${(po['totalAmount'] as num?)?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('New'),
              if (_newPOs.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                  child: Text('${_newPOs.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('In Progress'),
              if (_acceptedPOs.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                  child: Text('${_acceptedPOs.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ])),
            const Tab(text: 'Delivered'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPOs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPoList(_newPOs, isNew: true),
                _buildPoList(_acceptedPOs, isAccepted: true),
                _buildPoList(_deliveredPOs),
              ],
            ),
    );
  }

  Widget _buildPoList(List<Map<String, dynamic>> pos, {bool isNew = false, bool isAccepted = false}) {
    if (pos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('No POs', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadPOs,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: pos.length,
        itemBuilder: (ctx, i) => _buildPoCard(pos[i], isNew: isNew, isAccepted: isAccepted),
      ),
    );
  }

  Widget _buildPoCard(Map<String, dynamic> po, {bool isNew = false, bool isAccepted = false}) {
    final status = po['status'] ?? 'SENT';
    Color statusColor = Colors.orange;
    if (status == 'ACCEPTED') statusColor = Colors.blue;
    else if (status == 'DISPATCHED') statusColor = Colors.purple;
    else if (status == 'DELIVERED') statusColor = Colors.green;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            onTap: () => _showPoDetails(po),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.receipt, color: statusColor),
            ),
            title: Text(po['poNumber'] ?? 'PO', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${po['totalItems'] ?? 0} items • ${po['createdAt']?.toString().substring(0, 10) ?? ''}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${(po['totalAmount'] as num?)?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (isNew || isAccepted)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showPoDetails(po),
                      child: const Text('View Items'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isNew)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptPO(po),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        child: const Text('Accept'),
                      ),
                    ),
                  if (isAccepted && status == 'ACCEPTED')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _markDispatched(po),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        child: const Text('Dispatched'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
