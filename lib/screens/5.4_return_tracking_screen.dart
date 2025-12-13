import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';

class ReturnTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> dispatch;
  const ReturnTrackingScreen({super.key, required this.dispatch});

  @override
  State<ReturnTrackingScreen> createState() => _ReturnTrackingScreenState();
}

class _ReturnTrackingScreenState extends State<ReturnTrackingScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _vehicles = [];
  final Map<int, int> _returnedValues = {};  // Track values directly, not via controllers
  final Map<int, int> _maxValues = {};
  int? _returnVehicleId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper().database;

    final items = await db.query(
      'dispatch_items',
      where: 'dispatchId = ? AND itemType = ?',
      whereArgs: [widget.dispatch['id'], 'UTENSIL'],
    );

    final vehicles = await db.query('vehicles', where: 'isActive = 1');

    for (final item in items) {
      final id = item['id'] as int;
      final loaded = (item['loadedQty'] as int?) ?? 0;
      // Use saved returnedQty if exists, otherwise default to loaded (for new returns)
      final savedReturnedQty = (item['returnedQty'] as int?) ?? loaded;
      _returnedValues[id] = savedReturnedQty;
      _maxValues[id] = loaded;
    }

    setState(() {
      _items = items.map((i) => {...i}).toList();
      _vehicles = vehicles;
      _returnVehicleId = widget.dispatch['vehicleId'] as int?;
      _isLoading = false;
    });
  }

  void _updateValue(int id, int delta) {
    final max = _maxValues[id] ?? 0;
    final current = _returnedValues[id] ?? 0;
    final newValue = (current + delta).clamp(0, max);
    setState(() {
      _returnedValues[id] = newValue;
    });
  }

  void _setValue(int id, int value) {
    final max = _maxValues[id] ?? 0;
    setState(() {
      _returnedValues[id] = value.clamp(0, max);
    });
  }

  Future<void> _completeReturn() async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();

    for (final item in _items) {
      final id = item['id'] as int;
      final returnedQty = _returnedValues[id] ?? 0;
      final loadedQty = _maxValues[id] ?? 0;
      
      // Debug print to verify correct values
      print('💾 Saving Return: Item $id, Loaded: $loadedQty, Returned: $returnedQty, Missing: ${loadedQty - returnedQty}');
      
      await db.update(
        'dispatch_items',
        {
          'returnedQty': returnedQty,
          'status': 'RETURNED',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      // Note: Stock restoration happens in Unload screen after physical verification
    }

    await db.update(
      'dispatches',
      {
        'dispatchStatus': 'RETURNING',
        'returnVehicleId': _returnVehicleId,
        'returnTime': now,
      },
      where: 'id = ?',
      whereArgs: [widget.dispatch['id']],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Return tracked successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Return: ${widget.dispatch['customerName'] ?? 'Order'}'),
        backgroundColor: Colors.orange,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order: ${widget.dispatch['date']} | ${widget.dispatch['time'] ?? ''}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _returnVehicleId,
                decoration: const InputDecoration(
                  labelText: 'Return Vehicle',
                  border: OutlineInputBorder(),
                ),
                items: _vehicles.map((v) {
                  return DropdownMenuItem<int>(
                    value: v['id'] as int,
                    child: Text('${v['vehicleNo']} - ${v['driverName'] ?? 'N/A'}'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _returnVehicleId = v),
              ),
              const SizedBox(height: 16),
              const Text('Enter Returned Quantities',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('Use +/- buttons or tap to enter value',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final id = item['id'] as int;
                    final max = _maxValues[id] ?? 0;
                    final current = _returnedValues[id] ?? 0;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['itemName']?.toString() ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Loaded: $max',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                  // Show missing count if returned < loaded
                                  if (current < max)
                                    Text(
                                      'Missing: ${max - current} nos',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Increment/Decrement buttons with editable center
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Minus button
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  iconSize: 32,
                                  onPressed: current > 0 
                                      ? () => _updateValue(id, -1) 
                                      : null,
                                ),
                                // Tappable value display
                                GestureDetector(
                                  onTap: () => _showValueEditor(id, current, max),
                                  child: Container(
                                    width: 50,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$current',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Plus button
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.green),
                                  iconSize: 32,
                                  onPressed: current < max 
                                      ? () => _updateValue(id, 1) 
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _completeReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Complete Return',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Show a dialog to manually enter value
  void _showValueEditor(int id, int currentValue, int maxValue) {
    final controller = TextEditingController(text: currentValue.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Quantity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Max: $maxValue', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text) ?? 0;
              _setValue(id, value);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
