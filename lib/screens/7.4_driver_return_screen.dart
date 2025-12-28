// MODULE: DRIVER RETURN SCREEN (v34)
// Features: Track return items, mark utensils returned/damaged/missing
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class DriverReturnScreen extends StatefulWidget {
  final Map<String, dynamic> dispatch;
  
  const DriverReturnScreen({super.key, required this.dispatch});

  @override
  State<DriverReturnScreen> createState() => _DriverReturnScreenState();
}

class _DriverReturnScreenState extends State<DriverReturnScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _returnables = [];
  Map<int, String> _itemStatus = {}; // itemId -> RETURNED, DAMAGED, MISSING
  Map<int, int> _returnedQty = {};

  @override
  void initState() {
    super.initState();
    _loadReturnables();
  }

  Future<void> _loadReturnables() async {
    setState(() => _isLoading = true);
    
    final db = await DatabaseHelper().database;
    final dispatchId = widget.dispatch['id'];
    
    // Get returnable items (utensils)
    final items = await db.rawQuery('''
      SELECT di.*, 
             (di.loadedQty - COALESCE(di.returnedQty, 0)) as pendingReturn
      FROM dispatch_items di
      WHERE di.dispatchId = ? AND di.itemType = 'UTENSIL'
    ''', [dispatchId]);
    
    _returnables = List<Map<String, dynamic>>.from(items);
    
    // Initialize status for each item
    for (var item in _returnables) {
      final id = item['id'] as int;
      _itemStatus[id] = 'RETURNED';
      _returnedQty[id] = (item['loadedQty'] as int?) ?? 0;
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _completeReturn() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Return?'),
        content: const Text('Mark all items as returned and complete this dispatch?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final db = await DatabaseHelper().database;
      final now = DateTime.now().toIso8601String();
      
      // Update each item
      for (var item in _returnables) {
        final id = item['id'] as int;
        final status = _itemStatus[id] ?? 'RETURNED';
        final returnedQty = _returnedQty[id] ?? 0;
        final loadedQty = (item['loadedQty'] as int?) ?? 0;
        
        await db.update('dispatch_items', {
          'returnedQty': status == 'RETURNED' ? returnedQty : 0,
          'status': status,
          'unloadedQty': status == 'RETURNED' ? returnedQty : 0,
        }, where: 'id = ?', whereArgs: [id]);
        
        // Update utensil stock (return to available)
        if (status == 'RETURNED') {
          await db.rawUpdate('''
            UPDATE utensils SET availableStock = availableStock + ? 
            WHERE name = ?
          ''', [returnedQty, item['itemName']]);
        }
        
        // For damaged/missing, record it (stock reduced)
        if (status == 'DAMAGED' || status == 'MISSING') {
          await db.rawUpdate('''
            UPDATE utensils SET totalStock = totalStock - ? 
            WHERE name = ?
          ''', [loadedQty - returnedQty, item['itemName']]);
        }
      }
      
      // Update dispatch as completed
      await db.update('dispatches', {
        'dispatchStatus': 'COMPLETED',
        'updatedAt': now,
      }, where: 'id = ?', whereArgs: [widget.dispatch['id']]);
      
      // Update order
      await db.update('orders', {
        'dispatchStatus': 'COMPLETED',
        'returnedAt': now,
      }, where: 'id = ?', whereArgs: [widget.dispatch['orderId']]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispatch completed!'), backgroundColor: Colors.green),
      );
      
      Navigator.pop(context, true);
      Navigator.pop(context, true); // Go back to home
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Return Items')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Items'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange.shade100,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Mark status for each item returned from customer',
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _returnables.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text('No returnable items', style: TextStyle(fontSize: 18)),
                  const Text('You can complete this dispatch', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _returnables.length,
              itemBuilder: (ctx, i) => _buildReturnItemCard(_returnables[i]),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary
            _buildReturnSummary(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _completeReturn,
                icon: const Icon(Icons.check),
                label: const Text('Complete Return'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnItemCard(Map<String, dynamic> item) {
    final id = item['id'] as int;
    final name = item['itemName'] ?? 'Item';
    final loadedQty = (item['loadedQty'] as int?) ?? 0;
    final status = _itemStatus[id] ?? 'RETURNED';
    final qty = _returnedQty[id] ?? loadedQty;
    
    Color statusColor = Colors.green;
    if (status == 'DAMAGED') statusColor = Colors.orange;
    if (status == 'MISSING') statusColor = Colors.red;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Loaded: $loadedQty', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Status selection
            Row(
              children: [
                _buildStatusChip(id, 'RETURNED', 'Returned', Colors.green, Icons.check_circle),
                const SizedBox(width: 8),
                _buildStatusChip(id, 'DAMAGED', 'Damaged', Colors.orange, Icons.warning),
                const SizedBox(width: 8),
                _buildStatusChip(id, 'MISSING', 'Missing', Colors.red, Icons.cancel),
              ],
            ),
            
            // Quantity input (if returned)
            if (status == 'RETURNED') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Qty Returned: '),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: qty > 0 ? () => setState(() => _returnedQty[id] = qty - 1) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.red,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  IconButton(
                    onPressed: qty < loadedQty ? () => setState(() => _returnedQty[id] = qty + 1) : null,
                    icon: const Icon(Icons.add_circle_outline),
                    color: Colors.green,
                  ),
                  Text(' / $loadedQty', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(int itemId, String status, String label, Color color, IconData icon) {
    final isSelected = _itemStatus[itemId] == status;
    
    return GestureDetector(
      onTap: () => setState(() => _itemStatus[itemId] = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnSummary() {
    int returned = 0, damaged = 0, missing = 0;
    
    for (var item in _returnables) {
      final id = item['id'] as int;
      switch (_itemStatus[id]) {
        case 'RETURNED': returned++; break;
        case 'DAMAGED': damaged++; break;
        case 'MISSING': missing++; break;
      }
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _summaryItem('Returned', returned, Colors.green),
        _summaryItem('Damaged', damaged, Colors.orange),
        _summaryItem('Missing', missing, Colors.red),
      ],
    );
  }

  Widget _summaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}
