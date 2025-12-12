// MODULE: DISPATCH LIST (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-07 | Features: Day-wise Order View, Production Status, Internal-only Ready Count
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '5.2_dispatch_screen.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class DispatchListScreen extends StatefulWidget {
  const DispatchListScreen({super.key});

  @override
  State<DispatchListScreen> createState() => _DispatchListScreenState();
}

class _DispatchListScreenState extends State<DispatchListScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  final List<DateTime> _dateList = [];

  @override
  void initState() {
    super.initState();
    _generateDateList();
    _loadOrders();
    // Auto-refresh every 60 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadOrders());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _generateDateList() {
    final today = DateTime.now();
    for (int i = 0; i < 30; i++) {
      _dateList.add(today.add(Duration(days: i)));
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Get orders for date with their dishes and dispatch status
    // Only count INTERNAL production for ready status
    // SUBCONTRACT: goes directly to venue (skip)
    // LIVE: we load ingredients, not dish (skip)
    final orders = await db.rawQuery('''
      SELECT o.*, 
             (SELECT COUNT(*) FROM dishes d WHERE d.orderId = o.id) as dishCount,
             (SELECT COUNT(*) FROM dishes d WHERE d.orderId = o.id AND d.productionType = 'INTERNAL') as internalCount,
             (SELECT COUNT(*) FROM dishes d WHERE d.orderId = o.id AND d.productionType = 'INTERNAL' AND d.productionStatus = 'COMPLETED') as internalReadyCount,
             dp.dispatchStatus as currentDispatchStatus,
             dp.id as dispatchId
      FROM orders o
      LEFT JOIN dispatches dp ON dp.orderId = o.id
      WHERE o.date = ?
      ORDER BY o.time ASC
    ''', [dateStr]);

    // For each order, get the dishes
    List<Map<String, dynamic>> ordersWithDishes = [];
    for (final order in orders) {
      final dishes = await db.query('dishes',
          where: 'orderId = ?', whereArgs: [order['id']], orderBy: 'name');
      ordersWithDishes.add({
        ...order,
        'dishes': dishes,
      });
    }

    setState(() {
      _orders = ordersWithDishes;
      _isLoading = false;
    });
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'LOADING': return Colors.blue;
      case 'DISPATCHED': return Colors.purple;
      case 'DELIVERED': return Colors.green;
      case 'RETURNING': return Colors.amber;
      case 'COMPLETED': return Colors.grey;
      default: return Colors.orange;
    }
  }

  Color _getProductionColor(String? status) {
    switch (status) {
      case 'PENDING': return Colors.red.shade100;
      case 'QUEUED': return Colors.orange.shade100;
      case 'COMPLETED': return Colors.green.shade100;
      default: return Colors.grey.shade100;
    }
  }

  String _getProductionLabel(BuildContext context, String? status) {
    switch (status) {
      case 'PENDING': return AppLocalizations.of(context)!.statusPending;
      case 'QUEUED': return AppLocalizations.of(context)!.statusInProduction;
      case 'COMPLETED': return AppLocalizations.of(context)!.statusReady;
      default: return AppLocalizations.of(context)!.unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dispatchListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Horizontal Date Picker
          Container(
            height: 80,
            color: Colors.indigo.shade50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _dateList.length,
              itemBuilder: (ctx, i) {
                final date = _dateList[i];
                final isSelected = DateFormat('yyyy-MM-dd').format(date) ==
                    DateFormat('yyyy-MM-dd').format(_selectedDate);
                final isToday = DateFormat('yyyy-MM-dd').format(date) ==
                    DateFormat('yyyy-MM-dd').format(DateTime.now());
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = date);
                    _loadOrders();
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.indigo : (isToday ? Colors.indigo.shade100 : Colors.white),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? Colors.indigo : Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white : Colors.grey,
                          ),
                        ),
                        Text(
                          DateFormat('dd').format(date),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.noPendingOrdersDate(DateFormat('MMM dd').format(_selectedDate)),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (ctx, i) {
                          final order = _orders[i];
                          final dishes = (order['dishes'] as List?) ?? [];
                          final dishCount = order['dishCount'] ?? 0;
                          // Only INTERNAL production needs to be ready
                          final internalCount = order['internalCount'] ?? 0;
                          final internalReadyCount = order['internalReadyCount'] ?? 0;
                          final dispatchStatus = order['currentDispatchStatus'] ?? 'PENDING';
                          // All INTERNAL dishes must be COMPLETED (SUBCONTRACT/LIVE are irrelevant)
                          final allReady = internalCount == 0 || internalReadyCount == internalCount;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Order Header
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(dispatchStatus).withOpacity(0.1),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      topRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order['customerName'] ?? AppLocalizations.of(context)!.unknown,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Text(
                                              '${order['time']} • ${order['location'] ?? 'N/A'}',
                                              style: TextStyle(color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(dispatchStatus),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              dispatchStatus,
                                              style: const TextStyle(color: Colors.white, fontSize: 11),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                            Text(
                                              internalCount > 0 
                                                  ? AppLocalizations.of(context)!.inHouseReady(internalReadyCount, internalCount)
                                                  : AppLocalizations.of(context)!.noInHouseItems,
                                              style: TextStyle(
                                              color: allReady ? Colors.green : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Dishes List
                                ...dishes.map((d) {
                                  final prodStatus = d['productionStatus'] ?? 'PENDING';
                                  final prodType = d['productionType'] ?? 'INTERNAL';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                                              Text('Pax: ${d['pax']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                            ],
                                          ),
                                        ),
                                        if (prodType != 'INTERNAL')
                                          Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: prodType == 'LIVE' ? Colors.amber.shade100 : Colors.purple.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              prodType,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: prodType == 'LIVE' ? Colors.amber.shade900 : Colors.purple.shade900,
                                              ),
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getProductionColor(prodStatus),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _getProductionLabel(context, prodStatus),
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                // Action Button
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: allReady
                                          ? () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => DispatchScreen(order: order),
                                                ),
                                              ).then((_) => _loadOrders());
                                            }
                                          : null,
                                      icon: const Icon(Icons.local_shipping),
                                      label: Text(allReady ? AppLocalizations.of(context)!.startDispatch : AppLocalizations.of(context)!.waitingForKitchen),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: allReady ? Colors.green : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
