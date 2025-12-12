// MODULE: RETURN TRACKING - REBUILT FINAL VERSION
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class ReturnScreen extends StatefulWidget {
  final int dispatchId;
  final Map<String, dynamic> order;
  const ReturnScreen({super.key, required this.dispatchId, required this.order});

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  // We use a dedicated model class to ensure stability
  List<_ReturnItemModel> _items = [];
  List<Map<String, dynamic>> _vehicles = [];
  int? _returnVehicleId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;

      final dispatch = await db.query('dispatches', where: 'id = ?', whereArgs: [widget.dispatchId]);
      if (dispatch.isEmpty) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final d = dispatch.first;
      _returnVehicleId = d['returnVehicleId'] as int?;

      // Get utensil items
      final items = await db.rawQuery('''
        SELECT * FROM dispatch_items WHERE dispatchId = ? AND itemType = 'UTENSIL' AND quantity > 0
      ''', [widget.dispatchId]);

      final vehicles = await db.query('vehicles', where: 'isActive = 1');

      if (mounted) {
        setState(() {
          _items = items.map((i) => _ReturnItemModel.fromMap(i)).toList();
          _vehicles = List<Map<String, dynamic>>.from(vehicles);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.dispatchError(e))));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveReturn({bool closeScreen = false}) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();

    try {
      await db.update('dispatches', {
        'returnVehicleId': _returnVehicleId,
        'dispatchStatus': 'RETURNING',
        'updatedAt': now,
      }, where: 'id = ?', whereArgs: [widget.dispatchId]);

      for (final item in _items) {
        final status = item.returned >= item.loaded ? 'RETURNED' : 'MISSING';
        
        await db.update('dispatch_items', {
          'returnedQty': item.returned,
          'status': status,
        }, where: 'id = ?', whereArgs: [item.id]);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.returnSaved), backgroundColor: Colors.green),
        );
        if (closeScreen) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.saveFailed(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.returnTitle(widget.order['customerName'] ?? '')),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: () => _saveReturn(closeScreen: false)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle Section
                  Text(AppLocalizations.of(context)!.returnVehicle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _returnVehicleId,
                    items: _vehicles.map((v) => DropdownMenuItem(
                      value: v['id'] as int,
                      child: Text('${v['vehicleName']} (${v['vehicleNumber']})'),
                    )).toList(),
                    onChanged: (v) => setState(() => _returnVehicleId = v),
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    hint: Text(AppLocalizations.of(context)!.selectVehicle),
                  ),
                  const SizedBox(height: 24),

                  Text(AppLocalizations.of(context)!.items, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                     Padding(
                       padding: const EdgeInsets.all(16.0),
                       child: Text(AppLocalizations.of(context)!.noUtensilsReturn),
                     ),

                  // Use Column with specific children to avoid ListView recursion issues
                  ..._items.map((item) {
                     return _ReturnRowItem(
                       // CRITICAL: Stable Key based on ID
                       key: ValueKey(item.id), 
                       item: item,
                     );
                  }),

                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _saveReturn(closeScreen: true),
                      icon: const Icon(Icons.check),
                      label: Text(AppLocalizations.of(context)!.completeReturn),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// DATA MODEL
// ---------------------------------------------------------------------------
class _ReturnItemModel {
  final int id;
  final String name;
  final int loaded;
  int returned;

  _ReturnItemModel({
    required this.id,
    required this.name,
    required this.loaded,
    required this.returned,
  });

  factory _ReturnItemModel.fromMap(Map<String, dynamic> map) {
    final l = map['loadedQty'] as int? ?? 0;
    final q = map['quantity'] as int? ?? 0;
    // Fallback: if loaded is 0, use quantity (assuming full load or skipped loading step)
    final effectiveLoaded = l > 0 ? l : q;

    return _ReturnItemModel(
      id: map['id'],
      name: map['itemName'] ?? 'Unknown', // Keep 'Unknown' as internal default or add localized helper if needed, but model usually agnostic
      loaded: effectiveLoaded,
      returned: map['returnedQty'] ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGET
// ---------------------------------------------------------------------------
class _ReturnRowItem extends StatefulWidget {
  final _ReturnItemModel item;

  const _ReturnRowItem({super.key, required this.item});

  @override
  State<_ReturnRowItem> createState() => _ReturnRowItemState();
}

class _ReturnRowItemState extends State<_ReturnRowItem> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Initialize once. 
    // If returned is 0, show empty string for cleaner UI, or "0".
    // User requested "18" -> "81" fix, likely they prefer seeing what they type.
    final val = widget.item.returned;
    _controller = TextEditingController(text: val == 0 ? '' : val.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text('${AppLocalizations.of(context)!.loadedQty(widget.item.loaded)}', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            
            // Input Field
            Container(
              width: 90,
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  border: OutlineInputBorder(),
                  hintText: '0',
                ),
                onChanged: (val) {
                  // STRICT LOGIC:
                  
                  // 1. Empty? -> 0
                  if (val.isEmpty) {
                    widget.item.returned = 0;
                    return;
                  }

                  // 2. Parse
                  int? newVal = int.tryParse(val);
                  if (newVal == null) return; // Ignore garbage

                  // 3. Clamp
                  final max = widget.item.loaded;
                  if (newVal > max) {
                    newVal = max;
                    
                    // Force UI update to clamped value immediately
                    // This prevents "12" appearing when max is 10.
                    final txt = newVal.toString();
                    _controller.value = TextEditingValue(
                      text: txt,
                      selection: TextSelection.collapsed(offset: txt.length),
                    );
                  }

                  // 4. Update Model
                  widget.item.returned = newVal;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
