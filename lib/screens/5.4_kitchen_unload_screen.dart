// MODULE: KITCHEN UNLOAD - REBUILT FINAL VERSION
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class KitchenUnloadScreen extends StatefulWidget {
  final int dispatchId;
  final Map<String, dynamic> order;
  const KitchenUnloadScreen({super.key, required this.dispatchId, required this.order});

  @override
  State<KitchenUnloadScreen> createState() => _KitchenUnloadScreenState();
}

class _KitchenUnloadScreenState extends State<KitchenUnloadScreen> {
  // Using dedicated model for stability
  List<_UnloadItemModel> _items = [];
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
      
      final items = await db.rawQuery('''
        SELECT * FROM dispatch_items 
        WHERE dispatchId = ? AND itemType = 'UTENSIL' AND quantity > 0
      ''', [widget.dispatchId]);

      if (mounted) {
        setState(() {
          _items = items.map((i) => _UnloadItemModel.fromMap(i)).toList();
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

  Future<void> _saveUnload({bool isClosing = false}) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();

    try {
      // 1. Update Items
      for (final item in _items) {
        final status = item.unloaded >= item.loaded ? 'VERIFIED' : 'MISSING';
        
        await db.update('dispatch_items', {
          'unloadedQty': item.unloaded,
          'status': status,
          'notes': item.notes,
        }, where: 'id = ?', whereArgs: [item.id]);
      }

      // 2. Finalize if closing
      if (isClosing) {
         await _finalizeClose(db, now);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.savedMsg), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.saveFailed(e))));
      }
    }
  }

  Future<void> _finalizeClose(dynamic db, String now) async {
    final missing = _items.where((i) => i.unloaded < i.loaded).toList();

    await db.update('dispatches', {
      'dispatchStatus': 'COMPLETED',
      'updatedAt': now,
    }, where: 'id = ?', whereArgs: [widget.dispatchId]);

    await db.update('orders', {
      'dispatchStatus': 'COMPLETED',
    }, where: 'id = ?', whereArgs: [widget.order['id']]);

    if (mounted) {
      if (missing.isNotEmpty) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.missingItems, style: const TextStyle(color: Colors.red)),
            content: SizedBox(
               width: double.maxFinite,
               child: ListView.builder(
                 shrinkWrap: true,
                 itemCount: missing.length,
                 itemBuilder: (ctx, i) {
                   final item = missing[i];
                   return ListTile(
                     dense: true,
                     contentPadding: EdgeInsets.zero,
                     title: Text(item.name),
                     subtitle: Text(AppLocalizations.of(context)!.reason(item.notes.isEmpty ? '-' : item.notes)),
                     trailing: Text('${item.unloaded} / ${item.loaded}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                   );
                 },
               ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx), 
                child: Text(AppLocalizations.of(context)!.acknowledgeClose)
              )
            ],
          ),
        );
      }
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.unloadTitle(widget.order['customerName'] ?? '')),
        actions: [
          IconButton(
            icon: const Icon(Icons.save), 
            onPressed: () => _saveUnload(isClosing: false)
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              // Use Column prevents ListView rebuild recursion
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(AppLocalizations.of(context)!.verifyItems, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   const SizedBox(height: 8),

                   if (_items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(AppLocalizations.of(context)!.noUtensilsUnload),
                      ),

                   ..._items.map((item) {
                      return _UnloadRowItem(
                        // CRITICAL: Stable Key
                        key: ValueKey(item.id),
                        item: item,
                      );
                   }),

                   const SizedBox(height: 48),
                   
                   SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _saveUnload(isClosing: true),
                        icon: const Icon(Icons.done_all),
                        label: Text(AppLocalizations.of(context)!.closeOrder),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, 
                          foregroundColor: Colors.white
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
class _UnloadItemModel {
  final int id;
  final String name;
  final int loaded;
  int unloaded;
  String notes;

  _UnloadItemModel({
    required this.id,
    required this.name,
    required this.loaded,
    required this.unloaded,
    required this.notes,
  });

  factory _UnloadItemModel.fromMap(Map<String, dynamic> map) {
    final l = map['loadedQty'] as int? ?? 0;
    final q = map['quantity'] as int? ?? 0;
    final effectiveLoaded = l > 0 ? l : q;

    return _UnloadItemModel(
      id: map['id'],
      name: map['itemName'] ?? 'Unknown', // internal model default, likely won't be seen by user directly or handled in UI
      loaded: effectiveLoaded,
      unloaded: map['unloadedQty'] ?? 0,
      notes: map['notes'] ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGET
// ---------------------------------------------------------------------------
class _UnloadRowItem extends StatefulWidget {
  final _UnloadItemModel item;

  const _UnloadRowItem({super.key, required this.item});

  @override
  State<_UnloadRowItem> createState() => _UnloadRowItemState();
}

class _UnloadRowItemState extends State<_UnloadRowItem> {
  late TextEditingController _qtyController;
  late TextEditingController _notesController;
  
  // NOTE: We do NOT auto-show notes on validation to avoid layout shift.
  // User must manually tap icon to add notes.
  bool _showNotes = false;

  @override
  void initState() {
    super.initState();
    final val = widget.item.unloaded;
    _qtyController = TextEditingController(text: val == 0 ? '' : val.toString());
    _notesController = TextEditingController(text: widget.item.notes);
    
    // Notes visible if existing note or if explicitly enabled previous session? 
    // Let's just show if it has content initially.
    _showNotes = widget.item.notes.isNotEmpty;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                         widget.item.name, 
                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                      const SizedBox(height: 4),
                      Text('${AppLocalizations.of(context)!.loadedQty(widget.item.loaded)}', style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                
                // Notes Toggle Button
                IconButton(
                  icon: Icon(
                    Icons.note_add, 
                    color: _showNotes ? Colors.blue : Colors.grey.shade400
                  ),
                  onPressed: () {
                    // Manual layout shift only when user requested
                    setState(() => _showNotes = !_showNotes);
                  },
                ),

                const SizedBox(width: 8),
                
                // Qty Input
                Container(
                  width: 90,
                  height: 45,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                       contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                       border: OutlineInputBorder(),
                       hintText: '0',
                    ),
                    onChanged: (val) {
                       // STRICT LOGIC
                       
                       // 1. Empty? -> 0
                       if (val.isEmpty) {
                         widget.item.unloaded = 0;
                         return;
                       }
                       
                       // 2. Parse
                       int? intVal = int.tryParse(val);
                       if (intVal == null) return;
                       
                       // 3. Clamp
                       final max = widget.item.loaded;
                       if (intVal > max) {
                         intVal = max;
                         
                         // Force UI update
                         final txt = intVal.toString();
                         _qtyController.value = TextEditingValue(
                           text: txt,
                           selection: TextSelection.collapsed(offset: txt.length),
                         );
                       }
                       
                       // 4. Update Model
                       widget.item.unloaded = intVal;
                       
                       // NO setState logic for auto-notes here.
                    },
                  ),
                ),
              ],
            ),
            
            // Notes Field (Conditional)
            if (_showNotes)
               Padding(
                 padding: const EdgeInsets.only(top: 12.0),
                 child: TextField(
                   controller: _notesController,
                   decoration: InputDecoration(
                     labelText: AppLocalizations.of(context)!.reasonMismatch,
                     isDense: true,
                     border: const OutlineInputBorder(),
                     prefixIcon: const Icon(Icons.note, size: 18),
                   ),
                   onChanged: (val) {
                      widget.item.notes = val;
                   },
                 ),
               ),
          ],
        ),
      ),
    );
  }
}
