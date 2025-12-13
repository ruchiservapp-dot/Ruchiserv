import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';

class UnloadVerifyScreen extends StatefulWidget {
  final Map<String, dynamic> dispatch;
  const UnloadVerifyScreen({super.key, required this.dispatch});

  @override
  State<UnloadVerifyScreen> createState() => _UnloadVerifyScreenState();
}

class _UnloadVerifyScreenState extends State<UnloadVerifyScreen> {
  List<Map<String, dynamic>> _items = [];
  final Map<int, int> _verifiedValues = {};  // Track values directly, not via controllers
  final Map<int, int> _maxValues = {};
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

    for (final item in items) {
      final id = item['id'] as int;
      final loaded = (item['loadedQty'] as int?) ?? 0;
      // Use returnedQty from Return screen as the default value for unload verification
      final returnedQty = (item['returnedQty'] as int?) ?? loaded;
      
      // Only use saved unloadedQty if the item has already been verified (status = UNLOADED)
      // Otherwise, use returnedQty from the Return screen
      final status = item['status'] as String?;
      final savedUnloadedQty = (status == 'UNLOADED') 
          ? ((item['unloadedQty'] as int?) ?? returnedQty)
          : returnedQty;
      
      // Debug logging
      print('📦 Unload Load: Item $id, loaded=$loaded, returnedQty=$returnedQty, status=$status, using=$savedUnloadedQty');
      
      _verifiedValues[id] = savedUnloadedQty;
      _maxValues[id] = loaded;
    }

    setState(() {
      _items = items.map((i) => {...i}).toList();
      _isLoading = false;
    });
  }

  void _updateValue(int id, int delta) {
    final max = _maxValues[id] ?? 0;
    final current = _verifiedValues[id] ?? 0;
    final newValue = (current + delta).clamp(0, max);
    setState(() {
      _verifiedValues[id] = newValue;
    });
  }

  void _setValue(int id, int value) {
    final max = _maxValues[id] ?? 0;
    setState(() {
      _verifiedValues[id] = value.clamp(0, max);
    });
  }

  int _calculateVariance(int id) {
    final loaded = _maxValues[id] ?? 0;
    final verified = _verifiedValues[id] ?? 0;
    return loaded - verified;
  }

  Future<void> _completeUnload() async {
    final db = await DatabaseHelper().database;

    for (final item in _items) {
      final id = item['id'] as int;
      final verifiedQty = _verifiedValues[id] ?? 0;
      final itemName = item['itemName']?.toString() ?? '';
      
      // Debug logging
      print('💾 Saving Unload: Item $id, verifiedQty=$verifiedQty, name=$itemName');
      
      await db.update(
        'dispatch_items',
        {
          'unloadedQty': verifiedQty,
          'status': 'UNLOADED',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      
      // Restore verified utensil stock back to inventory
      if (itemName.isNotEmpty && verifiedQty > 0) {
        await db.rawUpdate('''
          UPDATE utensils 
          SET availableStock = availableStock + ? 
          WHERE name = ?
        ''', [verifiedQty, itemName]);
        print('📦 Restored $verifiedQty of "$itemName" to stock');
      }
    }

    await db.update(
      'dispatches',
      {'dispatchStatus': 'UNLOADED'},
      where: 'id = ?',
      whereArgs: [widget.dispatch['id']],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unload verified successfully'),
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
        title: Text('Verify: ${widget.dispatch['customerName'] ?? 'Order'}'),
        backgroundColor: Colors.purple,
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
              const Text('Verify Unloaded Quantities',
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
                    final current = _verifiedValues[id] ?? 0;
                    final variance = _calculateVariance(id);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                        'Sent: $max',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                            if (variance != 0)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Variance: $variance',
                                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                                ),
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
                  onPressed: _completeUnload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                  child: const Text('Complete & Close',
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
