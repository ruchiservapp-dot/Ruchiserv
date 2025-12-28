// MODULE: DRIVER ACTIVE DISPATCH SCREEN (v34)
// Features: Status timeline, stage transitions, GPS tracking, call/navigate actions
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database_helper.dart';
import '../services/location_service.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '7.4_driver_return_screen.dart';

class DriverActiveDispatchScreen extends StatefulWidget {
  final Map<String, dynamic> dispatch;
  
  const DriverActiveDispatchScreen({super.key, required this.dispatch});

  @override
  State<DriverActiveDispatchScreen> createState() => _DriverActiveDispatchScreenState();
}

class _DriverActiveDispatchScreenState extends State<DriverActiveDispatchScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _dispatch = {};
  Map<String, dynamic> _order = {};
  List<Map<String, dynamic>> _items = [];
  bool _gpsEnabled = false;
  
  // KM tracking
  final TextEditingController _kmForwardController = TextEditingController();
  final TextEditingController _kmReturnController = TextEditingController();

  final List<Map<String, dynamic>> _stages = [
    {'id': 'LOADING', 'label': 'Loading', 'icon': Icons.inventory_2, 'color': Colors.orange},
    {'id': 'DISPATCHED', 'label': 'In Transit', 'icon': Icons.local_shipping, 'color': Colors.blue},
    {'id': 'DELIVERED', 'label': 'Delivered', 'icon': Icons.check_circle, 'color': Colors.green},
    {'id': 'RETURNING', 'label': 'Returning', 'icon': Icons.assignment_return, 'color': Colors.purple},
    {'id': 'COMPLETED', 'label': 'Completed', 'icon': Icons.verified, 'color': Colors.teal},
  ];

  @override
  void initState() {
    super.initState();
    _dispatch = Map<String, dynamic>.from(widget.dispatch);
    _kmForwardController.text = ((_dispatch['kmForward'] as num?)?.toStringAsFixed(1) ?? '0');
    _kmReturnController.text = ((_dispatch['kmReturn'] as num?)?.toStringAsFixed(1) ?? '0');
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    
    final db = await DatabaseHelper().database;
    final orderId = _dispatch['orderId'];
    
    // Refresh dispatch data
    final dispatches = await db.query('dispatches', where: 'id = ?', whereArgs: [_dispatch['id']]);
    if (dispatches.isNotEmpty) {
      _dispatch = Map<String, dynamic>.from(dispatches.first);
    }
    
    // Get order
    final orders = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (orders.isNotEmpty) {
      _order = Map<String, dynamic>.from(orders.first);
    }
    
    // Get dispatch items
    final items = await db.query('dispatch_items', where: 'dispatchId = ?', whereArgs: [_dispatch['id']]);
    _items = List<Map<String, dynamic>>.from(items);
    
    setState(() => _isLoading = false);
  }

  int _getCurrentStageIndex() {
    final status = _dispatch['dispatchStatus'] ?? 'LOADING';
    return _stages.indexWhere((s) => s['id'] == status).clamp(0, _stages.length - 1);
  }

  Future<void> _advanceStage() async {
    final currentIndex = _getCurrentStageIndex();
    if (currentIndex >= _stages.length - 1) return;
    
    final nextStage = _stages[currentIndex + 1];
    final nextStatus = nextStage['id'] as String;
    
    // If advancing to DISPATCHED, prompt for km
    if (nextStatus == 'DISPATCHED') {
      final kmConfirmed = await _showKmDialog('Enter forward distance', _kmForwardController, 'kmForward');
      if (!kmConfirmed) return;
    }
    
    // If advancing to RETURNING, prompt for return km
    if (nextStatus == 'RETURNING') {
      final kmConfirmed = await _showKmDialog('Enter return distance (optional)', _kmReturnController, 'kmReturn');
      if (!kmConfirmed) return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark as ${nextStage['label']}?'),
        content: Text('This will update the dispatch status to "${nextStage['label']}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: nextStage['color']),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final db = await DatabaseHelper().database;
      final now = DateTime.now().toIso8601String();
      
      Map<String, dynamic> updates = {
        'dispatchStatus': nextStatus,
        'updatedAt': now,
      };
      
      if (nextStatus == 'DISPATCHED') {
        updates['dispatchTime'] = now;
        updates['kmForward'] = double.tryParse(_kmForwardController.text) ?? 0;
      } else if (nextStatus == 'DELIVERED') {
        updates['deliveredAt'] = now;
      } else if (nextStatus == 'RETURNING') {
        updates['returnTime'] = now;
        updates['kmReturn'] = double.tryParse(_kmReturnController.text) ?? 0;
      }
      
      await db.update('dispatches', updates, where: 'id = ?', whereArgs: [_dispatch['id']]);
      
      // Update order status
      await db.update('orders', {'dispatchStatus': nextStatus}, where: 'id = ?', whereArgs: [_dispatch['orderId']]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as ${nextStage['label']}'), backgroundColor: nextStage['color']),
      );
      
      _loadDetails();
      
      // If completed, go to return screen
      if (nextStatus == 'RETURNING') {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DriverReturnScreen(dispatch: _dispatch),
        )).then((_) => _loadDetails());
      }
    }
  }

  Future<bool> _showKmDialog(String title, TextEditingController controller, String field) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Distance (km)',
            border: OutlineInputBorder(),
            suffixText: 'km',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _toggleGps() async {
    if (_gpsEnabled) {
      LocationService.instance.stopTracking();
      setState(() => _gpsEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS tracking disabled')),
      );
    } else {
      try {
        await LocationService.instance.startTracking(_dispatch['id'] as int);
        setState(() => _gpsEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS tracking enabled'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _callCustomer() async {
    final mobile = _order['mobile'] ?? '';
    if (mobile.toString().isNotEmpty) {
      final url = Uri.parse('tel:$mobile');
      if (await canLaunchUrl(url)) await launchUrl(url);
    }
  }

  Future<void> _navigateToLocation() async {
    final location = _order['location'] ?? '';
    if (location.toString().isNotEmpty) {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}');
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Dispatch')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentIndex = _getCurrentStageIndex();
    final currentStage = _stages[currentIndex];
    final isCompleted = currentStage['id'] == 'COMPLETED';

    return Scaffold(
      appBar: AppBar(
        title: Text(_order['customerName'] ?? 'Dispatch'),
        actions: [
          IconButton(
            icon: Icon(_gpsEnabled ? Icons.gps_fixed : Icons.gps_not_fixed),
            color: _gpsEnabled ? Colors.green : null,
            onPressed: _toggleGps,
            tooltip: 'Toggle GPS',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Timeline
            _buildTimeline(currentIndex),
            const SizedBox(height: 24),
            
            // Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 16),
            
            // Order Summary
            _buildOrderSummary(),
            const SizedBox(height: 16),
            
            // KM Summary
            _buildKmSummary(),
            const SizedBox(height: 16),
            
            // Loaded Items
            _buildLoadedItems(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: !isCompleted ? Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
        ),
        child: ElevatedButton.icon(
          onPressed: _advanceStage,
          icon: Icon(_stages[currentIndex + 1]['icon']),
          label: Text('Mark as ${_stages[currentIndex + 1]['label']}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _stages[currentIndex + 1]['color'],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ) : Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.check),
          label: const Text('Dispatch Completed'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(int currentIndex) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_stages.length, (i) {
            final stage = _stages[i];
            final isActive = i == currentIndex;
            final isComplete = i < currentIndex;
            final color = isComplete || isActive ? stage['color'] : Colors.grey.shade300;
            
            return Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(isActive ? 1 : 0.2),
                      shape: BoxShape.circle,
                      border: isActive ? Border.all(color: color, width: 2) : null,
                    ),
                    child: Icon(
                      isComplete ? Icons.check : stage['icon'],
                      color: isComplete || isActive ? Colors.white : Colors.grey,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage['label'],
                    style: TextStyle(
                      fontSize: 9,
                      color: isActive ? color : Colors.grey,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _callCustomer,
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _navigateToLocation,
            icon: const Icon(Icons.navigation, size: 18),
            label: const Text('Navigate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            _infoRow('Customer', _order['customerName'] ?? 'N/A'),
            _infoRow('Location', _order['location'] ?? 'N/A'),
            _infoRow('Time', _order['time'] ?? 'N/A'),
            _infoRow('Pax', '${_order['totalPax'] ?? 0} guests'),
          ],
        ),
      ),
    );
  }

  Widget _buildKmSummary() {
    final kmForward = (_dispatch['kmForward'] as num?)?.toDouble() ?? 0;
    final kmReturn = (_dispatch['kmReturn'] as num?)?.toDouble() ?? 0;
    final totalKm = kmForward + kmReturn;
    final driverShare = (_dispatch['driverShare'] as num?)?.toDouble() ?? 0;
    
    return Card(
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _kmStatItem('Forward', kmForward, Icons.arrow_forward),
            _kmStatItem('Return', kmReturn, Icons.arrow_back),
            _kmStatItem('Total', totalKm, Icons.route),
            Column(
              children: [
                const Icon(Icons.currency_rupee, color: Colors.green),
                Text('₹${driverShare.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Earnings', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kmStatItem(String label, double km, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.indigo, size: 20),
        Text('${km.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLoadedItems() {
    if (_items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No items recorded for this dispatch'),
        ),
      );
    }
    
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Loaded Items (${_items.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final item = _items[i];
              return ListTile(
                dense: true,
                leading: Icon(
                  item['itemType'] == 'DISH' ? Icons.restaurant : Icons.inventory,
                  color: item['itemType'] == 'DISH' ? Colors.green : Colors.blue,
                ),
                title: Text(item['itemName'] ?? 'Item'),
                trailing: Text('${item['loadedQty'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
