// MODULE: DISPATCH & LOGISTICS (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-07 | Features: 4-Tab Layout (List, Active, Returns, Unload),
// Vehicle Selection, Consumables, Custom Utensils, Return Tracking, Unload Verification,
// GPS Tracking, Customer Notifications
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../db/aws/aws_api.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../services/feature_gate_service.dart';
import '../widgets/access_widgets.dart';

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _pendingOrders = [];
  List<Map<String, dynamic>> _activeDispatches = [];
  List<Map<String, dynamic>> _returns = [];
  List<Map<String, dynamic>> _unloads = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  final List<DateTime> _dateList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _generateDateList();
    _loadAllData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadAllData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _generateDateList() {
    final today = DateTime.now();
    for (int i = -7; i < 30; i++) {
      _dateList.add(today.add(Duration(days: i)));
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Tab 1: Pending Orders (ready for dispatch)
    final pending = await db.rawQuery('''
      SELECT o.*, 
             (SELECT COUNT(*) FROM dishes d WHERE d.orderId = o.id AND d.productionType = 'INTERNAL') as internalCount,
             (SELECT COUNT(*) FROM dishes d WHERE d.orderId = o.id AND d.productionType = 'INTERNAL' AND d.productionStatus = 'COMPLETED') as internalReadyCount,
             dp.dispatchStatus as currentDispatchStatus,
             dp.id as dispatchId
      FROM orders o
      LEFT JOIN dispatches dp ON dp.orderId = o.id
      WHERE o.date = ? AND (dp.dispatchStatus IS NULL OR dp.dispatchStatus = 'PENDING' OR dp.dispatchStatus = 'LOADING')
      ORDER BY o.time ASC
    ''', [dateStr]);

    // Tab 2: Active Dispatches (in-transit) - include vehicle details
    final active = await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.time, o.date, o.mobile, o.totalPax,
             v.vehicleNo, v.vehicleType, v.driverName, v.driverMobile
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      LEFT JOIN vehicles v ON v.id = d.vehicleId
      WHERE d.dispatchStatus IN ('DISPATCHED', 'DELIVERED')
      ORDER BY d.dispatchTime DESC
      LIMIT 50
    ''');

    // Tab 3: Returns (awaiting return tracking)
    final returns = await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date, o.mobile
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      WHERE d.dispatchStatus IN ('DISPATCHED', 'DELIVERED', 'RETURNING')
      ORDER BY d.dispatchTime DESC
      LIMIT 50
    ''');

    // Tab 4: Unloads (ready for verification)
    final unloads = await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      WHERE d.dispatchStatus = 'RETURNING'
      ORDER BY d.returnTime DESC
      LIMIT 50
    ''');

    // Get dishes for pending orders
    List<Map<String, dynamic>> pendingWithDishes = [];
    for (final order in pending) {
      final dishes = await db.query('dishes', where: 'orderId = ?', whereArgs: [order['id']]);
      pendingWithDishes.add({...order, 'dishes': dishes});
    }

    setState(() {
      _pendingOrders = pendingWithDishes;
      _activeDispatches = List<Map<String, dynamic>>.from(active);
      _returns = List<Map<String, dynamic>>.from(returns);
      _unloads = List<Map<String, dynamic>>.from(unloads);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dispatchTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: const Icon(Icons.list_alt), text: '${AppLocalizations.of(context)!.tabList} (${_pendingOrders.length})'),
            Tab(icon: const Icon(Icons.local_shipping), text: '${AppLocalizations.of(context)!.tabActive} (${_activeDispatches.length})'),
            Tab(icon: const Icon(Icons.assignment_return), text: '${AppLocalizations.of(context)!.tabReturns} (${_returns.length})'),
            Tab(icon: const Icon(Icons.inventory_2), text: '${AppLocalizations.of(context)!.tabUnload} (${_unloads.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date picker for Tab 1
          if (_tabController.index == 0) _buildDatePicker(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPendingTab(),
                      _buildActiveTab(),
                      _buildReturnsTab(),
                      _buildUnloadTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      height: 70,
      color: Colors.indigo.shade50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _dateList.length,
        itemBuilder: (ctx, i) {
          final date = _dateList[i];
          final isSelected = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(_selectedDate);
          final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadAllData();
            },
            child: Container(
              width: 55,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.indigo : (isToday ? Colors.indigo.shade100 : Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('EEE').format(date), style: TextStyle(fontSize: 9, color: isSelected ? Colors.white : Colors.grey)),
                  Text(DateFormat('dd').format(date), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
                  Text(DateFormat('MMM').format(date), style: TextStyle(fontSize: 9, color: isSelected ? Colors.white70 : Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Tab 1: Pending Orders
  Widget _buildPendingTab() {
    if (_pendingOrders.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noPendingOrdersDate(DateFormat('MMM dd').format(_selectedDate))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pendingOrders.length,
      itemBuilder: (ctx, i) => _buildOrderCard(_pendingOrders[i]),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final dishes = (order['dishes'] as List?) ?? [];
    final internalCount = (order['internalCount'] as int?) ?? 0;
    final internalReady = (order['internalReadyCount'] as int?) ?? 0;
    final allReady = internalCount == 0 || internalReady == internalCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(order['customerName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${order['time']} • ${order['location'] ?? 'N/A'}'),
            trailing: Chip(
              label: Text(allReady ? AppLocalizations.of(context)!.ready : '$internalReady/$internalCount'),
              backgroundColor: allReady ? Colors.green.shade100 : Colors.orange.shade100,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: dishes.map<Widget>((d) {
                final type = d['productionType'] ?? 'INTERNAL';
                final status = d['productionStatus'] ?? 'PENDING';
                final pax = d['pax'] ?? 0;
                return Chip(
                  label: Text('${d['name']} (${pax})', style: const TextStyle(fontSize: 11)),
                  backgroundColor: status == 'COMPLETED' ? Colors.green.shade50 : Colors.grey.shade100,
                  avatar: type != 'INTERNAL' ? Icon(type == 'LIVE' ? Icons.restaurant : Icons.store, size: 14) : null,
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: allReady ? () => _startDispatch(order) : null,
                icon: const Icon(Icons.local_shipping),
                label: Text(allReady ? AppLocalizations.of(context)!.startDispatch : AppLocalizations.of(context)!.waitingForKitchen),
                style: ElevatedButton.styleFrom(backgroundColor: allReady ? Colors.green : Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab 2: Active Dispatches
  Widget _buildActiveTab() {
    if (_activeDispatches.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noActiveDispatches));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _activeDispatches.length,
      itemBuilder: (ctx, i) {
        final d = _activeDispatches[i];
        final vehicleNo = d['vehicleNo'] ?? 'N/A';
        final vehicleType = d['vehicleType'] ?? '';
        final driverName = d['driverName'] ?? 'N/A';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _showDispatchDetails(d),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text((d['customerName'] as String?) ?? 'Order', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: d['dispatchStatus'] == 'DELIVERED' ? Colors.green : Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${d['dispatchStatus']}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${d['date']} | ${d['time']} | ${d['location'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text('$vehicleNo${vehicleType.isNotEmpty ? ' [$vehicleType]' : ''}', style: const TextStyle(fontWeight: FontWeight.w500))),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(child: Text('$driverName | ${d['driverMobile'] ?? ''}', style: TextStyle(color: Colors.grey.shade700))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.tapToViewItems, style: TextStyle(fontSize: 11, color: Colors.indigo.shade400)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Tab 3: Returns
  Widget _buildReturnsTab() {
    if (_returns.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noReturnTracking));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _returns.length,
      itemBuilder: (ctx, i) {
        final d = _returns[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.assignment_return, color: Colors.white)),
            title: Text((d['customerName'] as String?) ?? 'Order'),
            subtitle: Text('${d['date']} | ${d['dispatchStatus']}'),
            trailing: ElevatedButton(
              onPressed: () => _trackReturn(d),
              child: Text(AppLocalizations.of(context)!.track),
            ),
          ),
        );
      },
    );
  }

  // Tab 4: Unload
  Widget _buildUnloadTab() {
    if (_unloads.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noUnloadItems));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _unloads.length,
      itemBuilder: (ctx, i) {
        final d = _unloads[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.inventory_2, color: Colors.white)),
            title: Text((d['customerName'] as String?) ?? 'Order'),
            subtitle: Text('${d['date']} | Returned'),
            trailing: ElevatedButton(
              onPressed: () => _verifyUnload(d),
              child: Text(AppLocalizations.of(context)!.verify),
            ),
          ),
        );
      },
    );
  }

  // Actions
  void _startDispatch(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _DispatchLoadingSheet(order: order)),
    ).then((_) => _loadAllData());
  }

  void _showLocation(Map<String, dynamic> dispatch) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.locationValues(dispatch['driverLat'], dispatch['driverLng']))),
    );
  }

  // Show dispatch details with loaded items
  void _showDispatchDetails(Map<String, dynamic> dispatch) async {
    final db = await DatabaseHelper().database;
    final items = await db.query('dispatch_items', where: 'dispatchId = ?', whereArgs: [dispatch['id']]);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text((dispatch['customerName'] as String?) ?? 'Order', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${dispatch['date']} | ${dispatch['time']} | ${dispatch['location'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.local_shipping, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('${dispatch['vehicleNo'] ?? 'N/A'}${(dispatch['vehicleType'] ?? '').toString().isNotEmpty ? ' [${dispatch['vehicleType']}]' : ''}'),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('${dispatch['driverName'] ?? 'N/A'} | ${dispatch['driverMobile'] ?? ''}'),
                ],
              ),
              const Divider(height: 24),
              Text(AppLocalizations.of(context)!.loadedItems, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text(AppLocalizations.of(context)!.noItemsRecorded))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: items.length,
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          final type = item['itemType'];
                          return ListTile(
                            dense: true,
                            leading: Icon(type == 'DISH' ? Icons.restaurant : Icons.inventory, color: type == 'DISH' ? Colors.green : Colors.blue),
                            title: Text(item['itemName'].toString()),
                            subtitle: Text(type.toString()),
                            trailing: Text('${AppLocalizations.of(context)!.loadedQty((item['loadedQty'] as int?) ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _trackReturn(dispatch);
                      },
                      icon: const Icon(Icons.assignment_return),
                      label: Text(AppLocalizations.of(context)!.trackReturn),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _trackReturn(Map<String, dynamic> dispatch) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ReturnTrackingSheet(dispatch: dispatch)),
    ).then((_) => _loadAllData());
  }

  void _verifyUnload(Map<String, dynamic> dispatch) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _UnloadVerifySheet(dispatch: dispatch)),
    ).then((_) => _loadAllData());
  }
}

// ======== DISPATCH LOADING SHEET ========
class _DispatchLoadingSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  const _DispatchLoadingSheet({required this.order});

  @override
  State<_DispatchLoadingSheet> createState() => _DispatchLoadingSheetState();
}

class _DispatchLoadingSheetState extends State<_DispatchLoadingSheet> {
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _consumables = []; // Paper Roll, Plates, Glass
  List<Map<String, dynamic>> _customUtensils = []; // User-added utensils
  List<String> _utensilSuggestions = []; // From DB for autocomplete
  int? _selectedVehicleId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper().database;
    final vehicles = await db.query('vehicles', where: 'isActive = 1');
    final dishes = await db.query('dishes', where: 'orderId = ?', whereArgs: [widget.order['id']]);
    final dbUtensils = await db.query('utensils');

    List<Map<String, dynamic>> items = [];
    
    // Categorize dishes by production type
    for (final d in dishes) {
      final prodType = d['productionType'] ?? 'INTERNAL';
      items.add({
        'type': 'DISH',
        'prodType': prodType, // INTERNAL, SUBCONTRACT, LIVE
        'name': d['name'],
        'qty': d['pax'] ?? 1,
        'loaded': prodType == 'INTERNAL', // Kitchen items pre-ticked
        'directToVenue': prodType == 'SUBCONTRACT', // Subcontract default goes to venue
        'notes': prodType == 'LIVE' ? 'Ingredients' : (prodType == 'SUBCONTRACT' ? 'Optional' : ''),
      });
    }
    
    // Fixed consumables (always show)
    final consumables = [
      {'type': 'CONSUMABLE', 'name': 'Paper Roll', 'qty': 0, 'icon': '📜'},
      {'type': 'CONSUMABLE', 'name': 'Plates', 'qty': 0, 'icon': '🍽️'},
      {'type': 'CONSUMABLE', 'name': 'Glass Cups', 'qty': 0, 'icon': '🥛'},
      {'type': 'CONSUMABLE', 'name': 'Napkins', 'qty': 0, 'icon': '🧻'},
      {'type': 'CONSUMABLE', 'name': 'Spoons', 'qty': 0, 'icon': '🥄'},
    ];

    // Utensil suggestions from DB
    final suggestions = dbUtensils.map((u) => u['name'].toString()).toList();

    setState(() {
      _vehicles = vehicles;
      _items = items;
      _consumables = consumables;
      _utensilSuggestions = suggestions;
      _isLoading = false;
    });
  }

  void _addCustomUtensil() {
    setState(() {
      _customUtensils.add({'type': 'UTENSIL', 'name': '', 'qty': 0});
    });
  }

  void _removeCustomUtensil(int index) {
    setState(() {
      _customUtensils.removeAt(index);
    });
  }

  Future<void> _completeDispatch() async {
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectVehicle)));
      return;
    }

    try {
      final db = await DatabaseHelper().database;
      final now = DateTime.now().toIso8601String();

      // Create dispatch
      final dispatchId = await db.insert('dispatches', {
        'orderId': widget.order['id'],
        'vehicleId': _selectedVehicleId,
        'dispatchStatus': 'DISPATCHED',
        'dispatchTime': now,
        'createdAt': now,
      });

      // Insert dish items
      for (final item in _items) {
        final qty = item['qty'];
        final qtyInt = qty is int ? qty : (int.tryParse(qty.toString()) ?? 0);
        if (qtyInt > 0 || item['type'] == 'DISH') {
          await db.insert('dispatch_items', {
            'dispatchId': dispatchId,
            'itemType': item['type'],
            'itemName': item['name'],
            'quantity': qtyInt,
            'loadedQty': qtyInt,
            'status': 'LOADED',
          });
        }
      }

      // Insert consumables (Paper Roll, Plates, Glass, etc.)
      for (final item in _consumables) {
        final qtyInt = item['qty'] as int? ?? 0;
        if (qtyInt > 0) {
          await db.insert('dispatch_items', {
            'dispatchId': dispatchId,
            'itemType': 'CONSUMABLE',
            'itemName': item['name'],
            'quantity': qtyInt,
            'loadedQty': qtyInt,
            'status': 'LOADED',
          });
        }
      }

      // Insert custom utensils
      for (final item in _customUtensils) {
        final name = item['name']?.toString() ?? '';
        final qtyInt = item['qty'] as int? ?? 0;
        if (name.isNotEmpty && qtyInt > 0) {
          await db.insert('dispatch_items', {
            'dispatchId': dispatchId,
            'itemType': 'UTENSIL',
            'itemName': name,
            'quantity': qtyInt,
            'loadedQty': qtyInt,
            'status': 'LOADED',
          });
        }
      }

      // Update order
      await db.update('orders', {'dispatchStatus': 'DISPATCHED', 'dispatchedAt': now}, where: 'id = ?', whereArgs: [widget.order['id']]);

      // Send notification (non-blocking)
      final vehicle = await db.query('vehicles', where: 'id = ?', whereArgs: [_selectedVehicleId]);
      if (vehicle.isNotEmpty) {
        try {
          await NotificationService.queueDispatchNotification(dispatchId: dispatchId, orderData: widget.order, vehicleData: vehicle.first);
        } catch (e) {
          print('Notification error: $e');
        }
      }

      // Start GPS (non-blocking) - ENTERPRISE FEATURE ONLY
      try {
        final gpsEnabled = await FeatureGateService.instance.isFeatureEnabled('GPS_TRACKING');
        if (gpsEnabled) {
          await LocationService.instance.startTracking(dispatchId);
        }
      } catch (e) {
        print('GPS tracking error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.dispatchedMsg), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Dispatch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.dispatchError(e)), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildItemSection({
    required String title,
    required String subtitle,
    required Color color,
    required List<Map<String, dynamic>> items,
    bool isUtensil = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
                  ],
                ),
              ),
              Text('${items.where((i) => i['loaded'] == true).length}/${items.length}', 
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
        ...items.map((item) {
          final index = _items.indexOf(item);
          if (isUtensil) {
            // Utensil: show quantity input
            return ListTile(
              dense: true,
              title: Text(item['name']),
              trailing: SizedBox(
                width: 70,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.qtyLabel, isDense: true, border: const OutlineInputBorder()),
                  controller: TextEditingController(text: '${item['qty']}'),
                  onChanged: (v) {
                    _items[index]['qty'] = int.tryParse(v) ?? 0;
                    _items[index]['loaded'] = (int.tryParse(v) ?? 0) > 0;
                  },
                ),
              ),
            );
          } else {
            // Dish: show checkbox
            return CheckboxListTile(
              dense: true,
              title: Text('${item['name']} (${item['qty']})'),
              subtitle: item['notes'] != null && item['notes'].toString().isNotEmpty 
                  ? Text(item['notes'], style: TextStyle(color: color, fontSize: 11)) 
                  : null,
              value: item['loaded'] ?? false,
              activeColor: color,
              onChanged: (v) => setState(() => _items[index]['loaded'] = v ?? false),
            );
          }
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Load: ${widget.order['customerName']}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedVehicleId,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.selectVehicle, border: const OutlineInputBorder()),
                  items: _vehicles.map((v) {
                    // Format: VehicleNo [Type] - DriverName
                    final vehicleNo = v['vehicleNo'] ?? '';
                    final vehicleType = v['vehicleType'] ?? '';
                    final driverName = v['driverName'] ?? '';
                    final displayText = '$vehicleNo${vehicleType.isNotEmpty ? ' [$vehicleType]' : ''}${driverName.isNotEmpty ? ' - $driverName' : ''}';
                    return DropdownMenuItem<int>(value: v['id'] as int, child: Text(displayText));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedVehicleId = v),
                ),
                const SizedBox(height: 16),
                
                // === KITCHEN ITEMS (INTERNAL) ===
                _buildItemSection(
                  title: AppLocalizations.of(context)!.kitchenItems,
                  subtitle: AppLocalizations.of(context)!.kitchenItemsSubtitle,
                  color: Colors.green,
                  items: _items.where((i) => i['prodType'] == 'INTERNAL').toList(),
                ),
                
                // === SUBCONTRACT ITEMS ===
                _buildItemSection(
                  title: AppLocalizations.of(context)!.subcontractItems,
                  subtitle: AppLocalizations.of(context)!.subcontractItemsSubtitle,
                  color: Colors.purple,
                  items: _items.where((i) => i['prodType'] == 'SUBCONTRACT').toList(),
                ),
                
                // === LIVE ITEMS ===
                _buildItemSection(
                  title: AppLocalizations.of(context)!.liveCookingItems,
                  subtitle: AppLocalizations.of(context)!.liveCookingItemsSubtitle,
                  color: Colors.orange,
                  items: _items.where((i) => i['prodType'] == 'LIVE').toList(),
                ),
                
                // === CONSUMABLES (Paper Roll, Plates, Glass) ===
                Container(
                  margin: const EdgeInsets.only(top: 16, bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📦 Consumables', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                      const Text('Enter quantities for disposables', style: TextStyle(fontSize: 11, color: Colors.teal)),
                    ],
                  ),
                ),
                ..._consumables.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  return ListTile(
                    dense: true,
                    leading: Text(item['icon'] ?? '📦', style: const TextStyle(fontSize: 20)),
                    title: Text(item['name']),
                    trailing: SizedBox(
                      width: 70,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Qty', isDense: true, border: OutlineInputBorder()),
                        controller: TextEditingController(text: '${item['qty']}'),
                        onChanged: (v) => _consumables[i]['qty'] = int.tryParse(v) ?? 0,
                      ),
                    ),
                  );
                }),
                
                // === CUSTOM UTENSILS ===
                Container(
                  margin: const EdgeInsets.only(top: 16, bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🍴 Utensils & Equipment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text('Add returnable utensils', style: TextStyle(fontSize: 11, color: Colors.blue)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: _addCustomUtensil,
                      ),
                    ],
                  ),
                ),
                ..._customUtensils.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Autocomplete<String>(
                              optionsBuilder: (textEditingValue) {
                                if (textEditingValue.text.isEmpty) return _utensilSuggestions;
                                return _utensilSuggestions.where((s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                              },
                              initialValue: TextEditingValue(text: item['name'] ?? ''),
                              onSelected: (v) => _customUtensils[i]['name'] = v,
                              fieldViewBuilder: (ctx, controller, focusNode, onSubmit) => TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(labelText: 'Utensil Name', isDense: true, border: OutlineInputBorder()),
                                onChanged: (v) => _customUtensils[i]['name'] = v,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Qty', isDense: true, border: OutlineInputBorder()),
                              onChanged: (v) => _customUtensils[i]['qty'] = int.tryParse(v) ?? 0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => _removeCustomUtensil(i),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (_customUtensils.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Tap + to add utensils', style: TextStyle(color: Colors.grey)),
                  ),
                
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _completeDispatch, child: const Text('Complete Dispatch'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(48))),
              ],
            ),
    );
  }
}

// ======== RETURN TRACKING SHEET ========
class _ReturnTrackingSheet extends StatefulWidget {
  final Map<String, dynamic> dispatch;
  const _ReturnTrackingSheet({required this.dispatch});

  @override
  State<_ReturnTrackingSheet> createState() => _ReturnTrackingSheetState();
}

class _ReturnTrackingSheetState extends State<_ReturnTrackingSheet> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _vehicles = [];
  int? _returnVehicleId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper().database;
    // Only load UTENSIL items - dishes and consumables are consumed, not returned
    final items = await db.query('dispatch_items', 
      where: 'dispatchId = ? AND itemType = ?', 
      whereArgs: [widget.dispatch['id'], 'UTENSIL']);
    final vehicles = await db.query('vehicles', where: 'isActive = 1');
    
    setState(() {
      _items = items.map((i) => {...i, 'returnedQty': i['loadedQty'] ?? 0}).toList();
      _vehicles = vehicles;
      _returnVehicleId = widget.dispatch['vehicleId'] as int?;
      _isLoading = false;
    });
  }

  Future<void> _completeReturn() async {
    try {
      final db = await DatabaseHelper().database;
      final now = DateTime.now().toIso8601String();

      // Update dispatch items with returned quantities
      for (final item in _items) {
        await db.update('dispatch_items', 
          {'returnedQty': item['returnedQty'], 'status': 'RETURNED'},
          where: 'id = ?', whereArgs: [item['id']]);
      }

      // Update dispatch status
      await db.update('dispatches', {
        'dispatchStatus': 'RETURNING',
        'returnVehicleId': _returnVehicleId,
        'returnTime': now,
        'updatedAt': now,
      }, where: 'id = ?', whereArgs: [widget.dispatch['id']]);

      // Update order status
      await db.update('orders', {'dispatchStatus': 'RETURNING', 'returnedAt': now}, 
        where: 'id = ?', whereArgs: [widget.dispatch['orderId']]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return tracked!'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Return: ${(widget.dispatch['customerName'] as String?) ?? 'Order'}'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Order: ${widget.dispatch['date']} | ${widget.dispatch['time']}', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _returnVehicleId,
                  decoration: const InputDecoration(labelText: 'Return Vehicle', border: OutlineInputBorder()),
                  items: _vehicles.map((v) => DropdownMenuItem<int>(
                    value: v['id'] as int,
                    child: Text('${v['vehicleNo']} - ${v['driverName'] ?? 'N/A'}'),
                  )).toList(),
                  onChanged: (v) => setState(() => _returnVehicleId = v),
                ),
                const SizedBox(height: 16),
                const Text('Enter Returned Quantities', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._items.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  final loaded = item['loadedQty'] ?? 0;
                  final returned = item['returnedQty'] ?? 0;
                  final variance = loaded - returned;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: variance > 0 ? Colors.red.shade50 : null,
                    child: ListTile(
                      title: Text(item['itemName'].toString()),
                      subtitle: Text('Loaded: $loaded${variance > 0 ? ' | Missing: $variance' : ''}'),
                      trailing: SizedBox(
                        width: 70,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Returned', isDense: true, border: OutlineInputBorder()),
                          controller: TextEditingController(text: '$returned'),
                          onChanged: (v) => setState(() => _items[i]['returnedQty'] = int.tryParse(v) ?? 0),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _completeReturn,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size.fromHeight(48)),
                  child: const Text('Complete Return'),
                ),
              ],
            ),
    );
  }
}

// ======== UNLOAD VERIFY SHEET ========
class _UnloadVerifySheet extends StatefulWidget {
  final Map<String, dynamic> dispatch;
  const _UnloadVerifySheet({required this.dispatch});

  @override
  State<_UnloadVerifySheet> createState() => _UnloadVerifySheetState();
}

class _UnloadVerifySheetState extends State<_UnloadVerifySheet> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  int _totalVariance = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper().database;
    // Only load UTENSIL items for unload verification
    final items = await db.query('dispatch_items', 
      where: 'dispatchId = ? AND itemType = ?', 
      whereArgs: [widget.dispatch['id'], 'UTENSIL']);
    
    // Calculate variance
    int totalVar = 0;
    final itemsWithVariance = items.map((i) {
      final loaded = (i['loadedQty'] as int?) ?? 0;
      final returned = (i['returnedQty'] as int?) ?? 0;
      final unloaded = returned; // Pre-fill with returned qty
      final variance = loaded - returned;
      totalVar += variance;
      return {...i, 'unloadedQty': unloaded, 'variance': variance};
    }).toList();
    
    setState(() {
      _items = itemsWithVariance;
      _totalVariance = totalVar;
      _isLoading = false;
    });
  }

  Future<void> _completeUnload() async {
    try {
      final db = await DatabaseHelper().database;
      final now = DateTime.now().toIso8601String();

      // Update dispatch items with unloaded quantities
      for (final item in _items) {
        await db.update('dispatch_items', 
          {'unloadedQty': item['unloadedQty'], 'status': 'UNLOADED'},
          where: 'id = ?', whereArgs: [item['id']]);
      }

      // Update dispatch status to COMPLETED
      await db.update('dispatches', {
        'dispatchStatus': 'COMPLETED',
        'updatedAt': now,
      }, where: 'id = ?', whereArgs: [widget.dispatch['id']]);

      // Update order status
      await db.update('orders', {'dispatchStatus': 'COMPLETED'}, 
        where: 'id = ?', whereArgs: [widget.dispatch['orderId']]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_totalVariance > 0 
              ? 'Completed with ${_totalVariance} items missing' 
              : 'Dispatch completed successfully!'),
            backgroundColor: _totalVariance > 0 ? Colors.orange : Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verify: ${(widget.dispatch['customerName'] as String?) ?? 'Order'}'),
        backgroundColor: Colors.purple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 80, color: Colors.green),
                      const SizedBox(height: 16),
                      const Text('No utensils to verify', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _completeUnload,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Complete & Close'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Order: ${widget.dispatch['date']} | ${widget.dispatch['time'] ?? ''}', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    
                    // Summary Card
                    Card(
                      color: _totalVariance > 0 ? Colors.red.shade50 : Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Total Items', style: TextStyle(fontSize: 12)),
                                Text('${_items.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Missing', style: TextStyle(fontSize: 12)),
                                Text('$_totalVariance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _totalVariance > 0 ? Colors.red : Colors.green)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text('Utensil Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    
                    ..._items.asMap().entries.map((e) {
                      final i = e.key;
                      final item = e.value;
                      final loaded = item['loadedQty'] ?? 0;
                      final returned = item['returnedQty'] ?? 0;
                      final unloaded = item['unloadedQty'] ?? 0;
                      final variance = loaded - unloaded;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: variance > 0 ? Colors.red.shade50 : Colors.green.shade50,
                        child: ListTile(
                          leading: Icon(
                            variance > 0 ? Icons.warning : Icons.check_circle,
                            color: variance > 0 ? Colors.red : Colors.green,
                          ),
                          title: Text(item['itemName'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sent: $loaded | Returned: $returned'),
                              if (variance > 0)
                                Text('Missing: $variance', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          trailing: SizedBox(
                            width: 70,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Verify', isDense: true, border: OutlineInputBorder()),
                              controller: TextEditingController(text: '$unloaded'),
                              onChanged: (v) {
                                final newQty = int.tryParse(v) ?? 0;
                                setState(() {
                                  _items[i]['unloadedQty'] = newQty;
                                  // Recalculate total variance
                                  _totalVariance = _items.fold<int>(0, (sum, item) => 
                                    sum + ((item['loadedQty'] as int? ?? 0) - (item['unloadedQty'] as int? ?? 0)));
                                });
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _completeUnload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _totalVariance > 0 ? Colors.orange : Colors.green, 
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(_totalVariance > 0 ? 'Complete with Missing Items' : 'Complete & Close'),
                    ),
                  ],
                ),
    );
  }
}
