// MODULE: KITCHEN OPERATIONS (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-06 | Features: Orders View, Production Queue, Ready Screen, AWS Sync, Auto-refresh
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '../db/database_helper.dart';
import '../db/aws/aws_api.dart';
import '../services/connectivity_service.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  
  // Tab 1: Orders Data
  List<Map<String, dynamic>> _orders = [];
  // Tab 2: Production Queue Data
  List<Map<String, dynamic>> _productionQueue = [];
  // Tab 3: Ready Queue Data
  List<Map<String, dynamic>> _readyQueue = [];

  final List<DateTime> _dateList = [];
  Timer? _refreshTimer; // Auto-refresh for TV displays

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateDateList();
    _loadData();
    // Auto-refresh every 30 seconds for TV/shared displays
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }
  
  void _generateDateList() {
    final today = DateTime.now();
    for (int i = 0; i < 30; i++) {
      _dateList.add(today.add(Duration(days: i)));
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadOrdersForDate(),
      _loadProductionQueue(),
      _loadReadyQueue(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadOrdersForDate() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final orders = await DatabaseHelper().getOrdersByDate(dateStr);
    
    final List<Map<String, dynamic>> enriched = [];
    for (var o in orders) {
      final dishes = await DatabaseHelper().getDishesForOrder(o['id']);
      final map = Map<String, dynamic>.from(o);
      map['dishes'] = dishes;
      enriched.add(map);
    }
    _orders = enriched;
  }

  Future<void> _loadProductionQueue() async {
    // Fetch ALL active production items (Status = QUEUED) relative to today/future
    // ideally we modify DB helper to get dishes by status, but for now we can iterate relevant orders
    // Optimization: For now just show QUEUED items from selected date + next 7 days or simply fetch all QUEUED?
    // User requirement: "second screen is productio... based on timing all dishes will be quied"
    // I'll fetch ALL 'QUEUED' dishes across the system for simplicity.
    // Since SQL query for this is custom, I'll do a raw query here or add method. 
    // I'll use raw query for speed.
    final db = await DatabaseHelper().database;
    final res = await db.rawQuery('''
      SELECT d.*, o.date, o.time, o.customerName 
      FROM dishes d 
      JOIN orders o ON d.orderId = o.id 
      WHERE d.productionStatus = 'QUEUED' 
      ORDER BY o.date ASC, o.time ASC
    ''');
    _productionQueue = res;
  }

  Future<void> _loadReadyQueue() async {
    final db = await DatabaseHelper().database;
    final res = await db.rawQuery('''
      SELECT d.*, o.date, o.time, o.customerName 
      FROM dishes d 
      JOIN orders o ON d.orderId = o.id 
      WHERE d.productionStatus = 'COMPLETED' 
      ORDER BY d.readyAt DESC, o.date DESC, o.time DESC
    '''); // Newest ready first (by readyAt timestamp)
    _readyQueue = res;
  }

  Future<void> _updateDish(int id, Map<String, dynamic> updates) async {
    final db = await DatabaseHelper().database;
    
    // Auto-set readyAt timestamp when marking as COMPLETED
    if (updates['productionStatus'] == 'COMPLETED') {
      updates['readyAt'] = DateTime.now().toIso8601String();
    }
    
    await db.update('dishes', updates, where: 'id = ?', whereArgs: [id]);
    
    // AWS Sync: Push dish update to cloud
    _syncDishToAws(id, updates);
    
    _loadData();
  }

  /// Sync dish update to AWS (non-blocking)
  Future<void> _syncDishToAws(int dishId, Map<String, dynamic> updates) async {
    try {
      if (!await ConnectivityService().isOnline()) return;
      await AwsApi.callDbHandler(
        method: 'PUT',
        table: 'dishes',
        data: {...updates, 'id': dishId},
        filters: {'id': dishId},
      );
    } catch (e) {
      print('🔴 [AWS] Dish sync error: $e');
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupOrdersByMeal() {
    final Map<String, List<Map<String, dynamic>>> grouped = {
      'Breakfast': [], 'Lunch': [], 'Dinner': [], 'Other': []
    };
    for (var o in _orders) {
      final meal = (o['mealType'] as String?) ?? 'Other';
      if (grouped.containsKey(meal)) {
        grouped[meal]!.add(o);
      } else {
        grouped['Other']!.add(o);
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.kitchenOperations),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.ordersView),
            Tab(text: AppLocalizations.of(context)!.productionQueue),
            Tab(text: AppLocalizations.of(context)!.ready),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersTab(),
                _buildProductionTab(),
                _buildReadyTab(),
              ],
            ),
    );
  }

  // --- TAB 1: ORDERS ---
  Widget _buildOrdersTab() {
    final grouped = _groupOrdersByMeal();
    return Column(
      children: [
        _buildDateScroller(),
        Expanded(
          child: ordersList(grouped),
        ),
      ],
    );
  }
  
  Widget ordersList(Map<String, List<Map<String, dynamic>>> grouped) {
    if (_orders.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noOrdersFound));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (grouped['Breakfast']!.isNotEmpty) _buildMealSection(AppLocalizations.of(context)!.breakfast, grouped['Breakfast']!),
        if (grouped['Lunch']!.isNotEmpty) _buildMealSection(AppLocalizations.of(context)!.lunch, grouped['Lunch']!),
        if (grouped['Dinner']!.isNotEmpty) _buildMealSection(AppLocalizations.of(context)!.dinner, grouped['Dinner']!),
        if (grouped['Other']!.isNotEmpty) _buildMealSection(AppLocalizations.of(context)!.other, grouped['Other']!),
      ],
    );
  }

  Widget _buildDateScroller() {
    return Container(
      height: 80,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _dateList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final d = _dateList[i];
          final isSelected = DateFormat('yyyy-MM-dd').format(d) == DateFormat('yyyy-MM-dd').format(_selectedDate);
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = d);
              _loadData();
            },
            child: Container(
              width: 60,
              decoration: BoxDecoration(
                color: isSelected ? Colors.indigo : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? Colors.indigo : Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Text(DateFormat('MMM').format(d), style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey)),
                   Text(DateFormat('dd').format(d), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealSection(String title, List<Map<String, dynamic>> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
        ),
        ...orders.map((o) => _buildOrderCard(o)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final dishes = order['dishes'] as List<Map<String, dynamic>>;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(order['customerName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
                ),
                Text("${order['time']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text("${AppLocalizations.of(context)!.paxLabel(order['totalPax'] ?? 0)} | ${AppLocalizations.of(context)!.locLabel(order['location'] ?? AppLocalizations.of(context)!.na)}", style: TextStyle(color: Colors.grey.shade700)),
            const Divider(),
            ...dishes.map((d) => _buildDishRow(d)),
          ],
        ),
      ),
    );
  }

  Widget _buildDishRow(Map<String, dynamic> dish) {
    // Color coding: Internal(White/Default), Subcontract(Purple/Grey), Live(Orange)
    final type = dish['productionType'] ?? 'INTERNAL';
    final status = dish['productionStatus'] ?? 'PENDING';
    
    Color? bgColor;
    Color typeColor = Colors.grey;
    String typeLabel = type;
    
    if (type == 'SUBCONTRACT') {
      bgColor = Colors.purple.shade50;
      typeColor = Colors.purple;
      typeLabel = '🏪 ${AppLocalizations.of(context)!.subcontract}';
    }
    if (type == 'LIVE') {
      bgColor = Colors.orange.shade100; // More distinct orange
      typeColor = Colors.deepOrange;
      typeLabel = AppLocalizations.of(context)!.prepIngredients;
    }
    if (status == 'COMPLETED') bgColor = Colors.green.shade50; // Override if done

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: type == 'LIVE' ? Colors.orange : Colors.grey.shade200, width: type == 'LIVE' ? 2 : 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(dish['name'], style: const TextStyle(fontWeight: FontWeight.w600))),
                        if (type == 'LIVE')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(4)),
                            child: Text(AppLocalizations.of(context)!.live, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Text("${AppLocalizations.of(context)!.qty}: ${dish['pax']}", style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        if (type != 'INTERNAL')
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                             decoration: BoxDecoration(color: typeColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                             child: Text(typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor)),
                           ),
                      ],
                    ),
                  ],
                ),
              ),
              if (status == 'PENDING' && (type == 'INTERNAL' || type == 'LIVE'))
                ElevatedButton(
                  onPressed: () => _updateDish(dish['id'], {'productionStatus': 'QUEUED'}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: type == 'LIVE' ? Colors.deepOrange : Colors.orange, 
                    padding: const EdgeInsets.symmetric(horizontal: 12), 
                    minimumSize: const Size(60, 30),
                  ),
                  child: Text(type == 'LIVE' ? AppLocalizations.of(context)!.prep : AppLocalizations.of(context)!.start, style: const TextStyle(fontSize: 12)),
                )
              else if (status == 'QUEUED')
                Text(type == 'LIVE' ? AppLocalizations.of(context)!.prepping : AppLocalizations.of(context)!.inQueue, style: TextStyle(color: type == 'LIVE' ? Colors.deepOrange : Colors.orange, fontWeight: FontWeight.bold))
              else if (status == 'COMPLETED')
                const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
          if (status != 'COMPLETED')
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showDishOptions(dish),
              style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(AppLocalizations.of(context)!.assignEdit, style: const TextStyle(fontSize: 10)),
            ),
          )
        ],
      ),
    );
  }

  void _showDishOptions(Map<String, dynamic> dish) {
    showModalBottomSheet(context: context, builder: (_) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text(AppLocalizations.of(context)!.productionSettings, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 16),
             ListTile(
               leading: const Icon(Icons.kitchen),
               title: Text(AppLocalizations.of(context)!.internalKitchen),
               onTap: () {
                 _updateDish(dish['id'], {'productionType': 'INTERNAL'});
                 Navigator.pop(context);
               },
             ),
             ListTile(
               leading: const Icon(Icons.people),
               title: Text(AppLocalizations.of(context)!.subcontract),
               onTap: () {
                  // Could ask for subcontractor name logic here
                 _updateDish(dish['id'], {'productionType': 'SUBCONTRACT'});
                 Navigator.pop(context);
               },
             ),
             ListTile(
               leading: const Icon(Icons.local_fire_department),
               title: Text(AppLocalizations.of(context)!.liveCounter),
               onTap: () {
                 _updateDish(dish['id'], {'productionType': 'LIVE'});
                 Navigator.pop(context);
               },
             ),
          ],
        ),
      );
    });
  }

  // --- TAB 2: PRODUCTION QUEUE ---
  Widget _buildProductionTab() {
    if (_productionQueue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noItemsInQueue),
          ],
        ),
      );
    }
    // Group by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var d in _productionQueue) {
      final date = d['date'] ?? 'Unknown';
      grouped.putIfAbsent(date, () => []).add(d);
    }
    final sortedDates = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sortedDates.expand((date) {
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(date, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
          ),
          ...grouped[date]!.map((d) {
            final type = d['productionType'] ?? 'INTERNAL';
            final dishName = d['name'] as String;
            final pax = d['pax'] as int? ?? 1;
            
            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.all(12),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(dishName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text("${d['customerName']} • ${d['time']}"),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Text("${AppLocalizations.of(context)!.qty}: $pax", style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        if (type != 'INTERNAL')
                          Text("[$type]", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () => _updateDish(d['id'], {'productionStatus': 'COMPLETED'}),
                  icon: const Icon(Icons.check),
                  label: Text(AppLocalizations.of(context)!.done),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                // Ingredient Details (loaded on expand)
                children: [
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: DatabaseHelper().getRecipeForDishByName(dishName, pax),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final recipe = snapshot.data ?? [];
                      if (recipe.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(AppLocalizations.of(context)!.noRecipeDefined, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context)!.ingredientsRequired, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                          const SizedBox(height: 8),
                          ...recipe.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.fiber_manual_record, size: 8, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(r['ingredientName'] ?? 'Unknown')),
                                Text(
                                  "${(r['scaledQuantity'] as num?)?.toStringAsFixed(2) ?? '?'} ${r['unit'] ?? ''}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ];
      }).toList(),
    );
  }

  // --- TAB 3: READY SCREEN ---
  Widget _buildReadyTab() {
    if (_readyQueue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noReadyItems),
          ],
        ),
      );
    }
    // Group by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var d in _readyQueue) {
      final date = d['date'] ?? 'Unknown';
      grouped.putIfAbsent(date, () => []).add(d);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a)); // Newest first

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sortedDates.expand((date) {
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(date, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
          ),
          ...grouped[date]!.map((d) {
            final type = d['productionType'] ?? 'INTERNAL';
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.green.shade50,
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                title: Text(d['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text("${d['customerName']} • ${d['time']}"),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Text("${AppLocalizations.of(context)!.qty}: ${d['pax']}", style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        if (type != 'INTERNAL')
                          Text("[$type]", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () => _updateDish(d['id'], {'productionStatus': 'QUEUED'}),
                  icon: const Icon(Icons.undo, size: 16),
                  label: Text(AppLocalizations.of(context)!.returnItem),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, 
                    foregroundColor: Colors.red,
                    elevation: 0,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            );
          }),
        ];
      }).toList(),
    );
  }
}

