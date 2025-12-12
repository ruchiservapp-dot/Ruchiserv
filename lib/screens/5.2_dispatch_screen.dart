// MODULE: DISPATCH LOADING (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-07 | Features: Vehicle Assignment, Item Loading, GPS Tracking, Notifications
import 'dart:async';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../db/aws/aws_api.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class DispatchScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const DispatchScreen({super.key, required this.order});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _utensils = [];
  List<Map<String, dynamic>> _dishes = [];
  List<Map<String, dynamic>> _loadingItems = []; // Combined list for loading
  
  int? _selectedVehicleId;
  bool _isLoading = true;
  int? _dispatchId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;

    // Load vehicles
    final vehicles = await db.query('vehicles', where: 'isActive = 1');
    
    // Load utensils (master list)
    final utensils = await db.query('utensils');
    
    // Load dishes for this order
    final dishes = await db.query('dishes', where: 'orderId = ?', whereArgs: [widget.order['id']]);

    // Check if dispatch record exists
    final existing = await db.query('dispatches', where: 'orderId = ?', whereArgs: [widget.order['id']]);
    
    if (existing.isNotEmpty) {
      _dispatchId = existing.first['id'] as int;
      _selectedVehicleId = existing.first['vehicleId'] as int?;
      
      // Load existing dispatch items
      final items = await db.query('dispatch_items', where: 'dispatchId = ?', whereArgs: [_dispatchId]);
      setState(() {
        _loadingItems = items.map((i) => {...i}).toList();
      });
    } else {
      // Create initial loading items from dishes and utensils
      List<Map<String, dynamic>> items = [];
      
      // Add dishes
      for (final d in dishes) {
        items.add({
          'itemType': 'DISH',
          'itemName': d['name'],
          'quantity': d['pax'] ?? 1,
          'loadedQty': 0,
          'status': 'PENDING',
          'dishId': d['id'],
        });
      }
      
      // Add utensils with default quantities (user can edit)
      for (final u in utensils) {
        if (u['isReturnable'] == 1) { // Only returnable items need tracking
          items.add({
            'itemType': 'UTENSIL',
            'itemName': u['name'],
            'quantity': 0, // User will set
            'loadedQty': 0,
            'status': 'PENDING',
            'utensilId': u['id'],
            'category': u['category'],
          });
        }
      }
      
      setState(() => _loadingItems = items);
    }

    setState(() {
      _vehicles = vehicles;
      _utensils = utensils;
      _dishes = dishes;
      _isLoading = false;
    });
  }

  Future<void> _saveDispatch() async {
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectVehicle)),
      );
      return;
    }

    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();

    // Create or update dispatch record
    if (_dispatchId == null) {
      _dispatchId = await db.insert('dispatches', {
        'orderId': widget.order['id'],
        'vehicleId': _selectedVehicleId,
        'dispatchStatus': 'LOADING',
        'createdAt': now,
        'updatedAt': now,
      });

      // Insert dispatch items
      for (final item in _loadingItems) {
        if (item['quantity'] > 0 || item['itemType'] == 'DISH') {
          await db.insert('dispatch_items', {
            'dispatchId': _dispatchId,
            'itemType': item['itemType'],
            'itemName': item['itemName'],
            'quantity': item['quantity'],
            'loadedQty': item['loadedQty'],
            'status': item['status'],
          });
        }
      }
    } else {
      await db.update('dispatches', {
        'vehicleId': _selectedVehicleId,
        'updatedAt': now,
      }, where: 'id = ?', whereArgs: [_dispatchId]);

      // Update items
      for (final item in _loadingItems) {
        if (item['id'] != null) {
          await db.update('dispatch_items', {
            'quantity': item['quantity'],
            'loadedQty': item['loadedQty'],
            'status': item['status'],
          }, where: 'id = ?', whereArgs: [item['id']]);
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.savedMsg), backgroundColor: Colors.green),
    );
  }

  Future<void> _completeDispatch() async {
    // Check all items loaded
    final unloaded = _loadingItems.where((i) => 
      i['itemType'] == 'DISH' && i['status'] != 'LOADED'
    ).toList();

    if (unloaded.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.loadAllDishesFirst)),
      );
      return;
    }

    await _saveDispatch();

    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();

    // Update dispatch status
    await db.update('dispatches', {
      'dispatchStatus': 'DISPATCHED',
      'dispatchTime': now,
      'updatedAt': now,
    }, where: 'id = ?', whereArgs: [_dispatchId]);

    // Update order status
    await db.update('orders', {
      'dispatchStatus': 'DISPATCHED',
      'dispatchedAt': now,
    }, where: 'id = ?', whereArgs: [widget.order['id']]);

    // Sync to AWS
    _syncToAws();

    // Send notification to customer
    await _sendCustomerNotification();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.dispatchedNotifiedMsg), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _syncToAws() async {
    try {
      if (!await ConnectivityService().isOnline()) return;
      await AwsApi.callDbHandler(
        method: 'PUT',
        table: 'dispatches',
        data: {'id': _dispatchId, 'status': 'DISPATCHED'},
      );
    } catch (e) {
      print('AWS sync error: $e');
    }
  }

  Future<void> _sendCustomerNotification() async {
    // Get vehicle details
    final db = await DatabaseHelper().database;
    final vehicle = await db.query('vehicles', where: 'id = ?', whereArgs: [_selectedVehicleId]);
    
    if (vehicle.isEmpty) return;
    
    final v = vehicle.first;
    
    // Use NotificationService to queue WhatsApp/SMS
    try {
      await NotificationService.queueDispatchNotification(
        dispatchId: _dispatchId!,
        orderData: widget.order,
        vehicleData: v,
      );
      print('✅ Notification queued via NotificationService');
    } catch (e) {
      print('⚠️ Notification error: $e');
    }
    
    // Start GPS tracking for driver
    final trackingStarted = await LocationService.instance.startTracking(_dispatchId!);
    if (trackingStarted) {
      print('📍 GPS tracking started');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dishItems = _loadingItems.where((i) => i['itemType'] == 'DISH').toList();
    final utensilItems = _loadingItems.where((i) => i['itemType'] == 'UTENSIL').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dispatchCustomerTitle(widget.order['customerName'] ?? '')),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveDispatch),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📍 ${widget.order['location'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                          Text('🕐 ${widget.order['time']} | Pax: ${widget.order['totalPax']}'),
                          if (widget.order['mobile'] != null)
                            Text('📞 ${widget.order['mobile']}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Vehicle Selection
                  Text(AppLocalizations.of(context)!.selectVehicle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _selectedVehicleId,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: AppLocalizations.of(context)!.chooseVehicle,
                    ),
                    items: _vehicles.map((v) => DropdownMenuItem<int>(
                      value: v['id'] as int,
                      child: Text('${v['vehicleNo']} (${v['driverName'] ?? 'No driver'})'),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedVehicleId = v),
                  ),
                  const SizedBox(height: 24),

                  // Dishes Loading
                  const Text('Dishes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...dishItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final index = _loadingItems.indexOf(item);
                    final isLoaded = item['status'] == 'LOADED';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isLoaded ? Colors.green.shade50 : null,
                      child: ListTile(
                        leading: Checkbox(
                          value: isLoaded,
                          onChanged: (v) {
                            setState(() {
                              _loadingItems[index]['status'] = v! ? 'LOADED' : 'PENDING';
                              _loadingItems[index]['loadedQty'] = v ? item['quantity'] : 0;
                            });
                          },
                        ),
                        title: Text(item['itemName']),
                        subtitle: Text('${AppLocalizations.of(context)!.qtyLabel}: ${item['quantity']}'),
                        trailing: isLoaded
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.pending, color: Colors.orange),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Utensils Loading
                  Text(AppLocalizations.of(context)!.utensilsEquipment, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...utensilItems.asMap().entries.map((entry) {
                    final item = entry.value;
                    final index = _loadingItems.indexOf(item);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item['itemName']),
                        subtitle: Text(item['category'] ?? ''),
                        trailing: SizedBox(
                          width: 80,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.qtyLabel,
                              isDense: true,
                            ),
                            controller: TextEditingController(text: '${item['quantity']}'),
                            onChanged: (v) {
                              _loadingItems[index]['quantity'] = int.tryParse(v) ?? 0;
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 32),

                  // Dispatch Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _completeDispatch,
                      icon: const Icon(Icons.send),
                      label: Text(AppLocalizations.of(context)!.completeDispatchNotify),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
