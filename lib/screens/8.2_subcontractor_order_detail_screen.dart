// MODULE: SUBCONTRACTOR ORDER DETAIL SCREEN (v34)
// Features: Orders for a specific date with dish details
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class SubcontractorOrderDetailScreen extends StatefulWidget {
  final String date;
  final int subcontractorId;
  
  const SubcontractorOrderDetailScreen({super.key, required this.date, required this.subcontractorId});

  @override
  State<SubcontractorOrderDetailScreen> createState() => _SubcontractorOrderDetailScreenState();
}

class _SubcontractorOrderDetailScreenState extends State<SubcontractorOrderDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  int _totalPax = 0;
  int _totalDishes = 0;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    
    final db = await DatabaseHelper().database;
    
    // Get orders with subcontracted dishes for this date
    final orders = await db.rawQuery('''
      SELECT DISTINCT o.*, 
             (SELECT SUM(d2.pax) FROM dishes d2 WHERE d2.orderId = o.id AND d2.isSubcontracted = 1 AND d2.subcontractorId = ?) as assignedPax
      FROM orders o
      JOIN dishes d ON d.orderId = o.id
      WHERE d.isSubcontracted = 1 AND d.subcontractorId = ? AND o.date = ?
      ORDER BY o.time ASC
    ''', [widget.subcontractorId, widget.subcontractorId, widget.date]);
    
    // For each order, get the assigned dishes
    List<Map<String, dynamic>> ordersWithDishes = [];
    int totalPax = 0;
    int totalDishes = 0;
    
    for (var order in orders) {
      final dishes = await db.rawQuery('''
        SELECT * FROM dishes WHERE orderId = ? AND isSubcontracted = 1 AND subcontractorId = ?
      ''', [order['id'], widget.subcontractorId]);
      
      final orderMap = Map<String, dynamic>.from(order);
      orderMap['dishes'] = List<Map<String, dynamic>>.from(dishes);
      ordersWithDishes.add(orderMap);
      
      totalPax += (order['assignedPax'] as num?)?.toInt() ?? 0;
      totalDishes += dishes.length;
    }
    
    setState(() {
      _orders = ordersWithDishes;
      _totalPax = totalPax;
      _totalDishes = totalDishes;
      _isLoading = false;
    });
  }

  String _getDateLabel() {
    try {
      final date = DateTime.parse(widget.date);
      final today = DateTime.now();
      if (date.year == today.year && date.month == today.month && date.day == today.day) {
        return 'Today';
      }
      return DateFormat('EEEE, MMM d').format(date);
    } catch (_) {
      return widget.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getDateLabel()),
            Text('${_orders.length} orders • $_totalDishes dishes • $_totalPax pax', 
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No orders for this date'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _orders.length,
                  itemBuilder: (ctx, i) => _buildOrderCard(_orders[i]),
                ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final dishes = order['dishes'] as List<Map<String, dynamic>>? ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: CircleAvatar(
            backgroundColor: Colors.purple.shade100,
            child: Text(
              '${order['time'] ?? ''}',
              style: TextStyle(fontSize: 10, color: Colors.purple.shade800),
            ),
          ),
          title: Text(order['customerName'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(child: Text(order['location'] ?? 'N/A', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                ],
              ),
              Text('${order['assignedPax']} pax • ${dishes.length} dishes', style: TextStyle(color: Colors.purple.shade700)),
            ],
          ),
          children: [
            const Divider(),
            ...dishes.map((d) => _buildDishTile(d)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDishTile(Map<String, dynamic> dish) {
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.restaurant, size: 16, color: Colors.green.shade700),
      ),
      title: Text(dish['dishName'] ?? 'Dish'),
      subtitle: Text('${dish['category'] ?? ''} • ${dish['productionType'] ?? 'INTERNAL'}', style: const TextStyle(fontSize: 11)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.purple.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${dish['pax']} pax',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade800, fontSize: 12),
        ),
      ),
    );
  }
}
