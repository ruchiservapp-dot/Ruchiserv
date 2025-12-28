// MODULE: DRIVER DISPATCH DETAIL SCREEN (v34)
// Features: Full order details, customer info, dishes, utensils, loading checklist
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class DriverDispatchDetailScreen extends StatefulWidget {
  final Map<String, dynamic> dispatch;
  
  const DriverDispatchDetailScreen({super.key, required this.dispatch});

  @override
  State<DriverDispatchDetailScreen> createState() => _DriverDispatchDetailScreenState();
}

class _DriverDispatchDetailScreenState extends State<DriverDispatchDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _dispatch = {};
  Map<String, dynamic> _order = {};
  List<Map<String, dynamic>> _dishes = [];
  List<Map<String, dynamic>> _dispatchItems = [];
  List<Map<String, dynamic>> _utensils = [];
  List<Map<String, dynamic>> _consumables = [];

  @override
  void initState() {
    super.initState();
    _dispatch = widget.dispatch;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    
    final db = await DatabaseHelper().database;
    final orderId = _dispatch['orderId'];
    
    // Get order details
    final orders = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (orders.isNotEmpty) {
      _order = Map<String, dynamic>.from(orders.first);
    }
    
    // Get dishes for order
    final dishes = await db.query('dishes', where: 'orderId = ?', whereArgs: [orderId]);
    _dishes = List<Map<String, dynamic>>.from(dishes);
    
    // Get dispatch items (if already loaded)
    final dispatchId = _dispatch['id'];
    final items = await db.query('dispatch_items', where: 'dispatchId = ?', whereArgs: [dispatchId]);
    
    _dispatchItems = List<Map<String, dynamic>>.from(items);
    _utensils = _dispatchItems.where((i) => i['itemType'] == 'UTENSIL').toList();
    _consumables = _dispatchItems.where((i) => i['itemType'] == 'CONSUMABLE').toList();
    
    setState(() => _isLoading = false);
  }

  Future<void> _callCustomer() async {
    final mobile = _order['mobile'] ?? _dispatch['customerMobile'];
    if (mobile != null && mobile.toString().isNotEmpty) {
      final url = Uri.parse('tel:$mobile');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone not available')),
      );
    }
  }

  Future<void> _openMaps() async {
    final location = _order['location'] ?? _dispatch['location'];
    if (location != null && location.toString().isNotEmpty) {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
    }
  }

  Future<void> _acceptAndStart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept & Start Loading?'),
        content: const Text('This will mark the dispatch as accepted and you can begin loading items.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Start Loading'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final db = await DatabaseHelper().database;
      await db.update('dispatches', {
        'assignmentStatus': 'ACCEPTED',
        'acceptedAt': DateTime.now().toIso8601String(),
        'dispatchStatus': 'LOADING',
      }, where: 'id = ?', whereArgs: [_dispatch['id']]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment accepted! Start loading.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dispatch Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final customerName = _order['customerName'] ?? _dispatch['customerName'] ?? 'Customer';
    final location = _order['location'] ?? _dispatch['location'] ?? 'N/A';
    final date = _order['date'] ?? _dispatch['date'] ?? '';
    final time = _order['time'] ?? _dispatch['time'] ?? '';
    final pax = _order['totalPax'] ?? _dispatch['totalPax'] ?? 0;
    final mobile = _order['mobile'] ?? _dispatch['customerMobile'] ?? '';
    final assignmentStatus = _dispatch['assignmentStatus'] ?? 'PENDING';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customerName, style: const TextStyle(fontSize: 16)),
            Text('$date • $time', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.phone), onPressed: _callCustomer, tooltip: 'Call Customer'),
          IconButton(icon: const Icon(Icons.map), onPressed: _openMaps, tooltip: 'Navigate'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Info Card
            _buildSection('Customer Details', Icons.person, [
              _buildInfoRow('Name', customerName),
              _buildInfoRow('Phone', mobile),
              _buildInfoRow('Location', location),
              _buildInfoRow('Date & Time', '$date at $time'),
              _buildInfoRow('Pax', '$pax guests'),
            ]),
            
            const SizedBox(height: 16),
            
            // Dishes Section
            _buildSection('Dishes (${_dishes.length})', Icons.restaurant, [
              ..._dishes.map((d) => _buildDishItem(d)),
            ]),
            
            const SizedBox(height: 16),
            
            // Utensils Section (if any)
            if (_utensils.isNotEmpty) ...[
              _buildSection('Utensils (${_utensils.length})', Icons.inventory, [
                ..._utensils.map((u) => _buildItemRow(u)),
              ]),
              const SizedBox(height: 16),
            ],
            
            // Consumables Section (if any)
            if (_consumables.isNotEmpty) ...[
              _buildSection('Consumables (${_consumables.length})', Icons.receipt, [
                ..._consumables.map((c) => _buildItemRow(c)),
              ]),
              const SizedBox(height: 16),
            ],
            
            // KM and Route Info
            _buildSection('Trip Details', Icons.route, [
              _buildInfoRow('Source', _dispatch['sourceLocation'] ?? 'Kitchen'),
              _buildInfoRow('Destination', _dispatch['destinationLocation'] ?? location),
              if ((_dispatch['kmForward'] as num?)?.toDouble() != null && (_dispatch['kmForward'] as num) > 0)
                _buildInfoRow('Distance (Forward)', '${(_dispatch['kmForward'] as num).toStringAsFixed(1)} km'),
              if ((_dispatch['kmReturn'] as num?)?.toDouble() != null && (_dispatch['kmReturn'] as num) > 0)
                _buildInfoRow('Distance (Return)', '${(_dispatch['kmReturn'] as num).toStringAsFixed(1)} km'),
            ]),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: assignmentStatus == 'PENDING' ? Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _acceptAndStart,
                icon: const Icon(Icons.check),
                label: const Text('Accept & Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ) : null,
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.indigo, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildDishItem(Map<String, dynamic> dish) {
    final name = dish['dishName'] ?? dish['name'] ?? 'Dish';
    final category = dish['category'] ?? '';
    final pax = dish['pax'] ?? 0;
    final type = dish['productionType'] ?? 'INTERNAL';
    final status = dish['productionStatus'] ?? 'PENDING';
    
    Color statusColor = Colors.grey;
    if (status == 'COMPLETED') statusColor = Colors.green;
    else if (status == 'QUEUED') statusColor = Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('$category • $pax pax', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Chip(
            label: Text(status, style: TextStyle(color: statusColor, fontSize: 10)),
            backgroundColor: statusColor.withOpacity(0.1),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_box_outline_blank, size: 20),
      title: Text(item['itemName'] ?? 'Item'),
      trailing: Text('${item['quantity'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
