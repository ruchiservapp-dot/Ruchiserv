// MODULE: ALLOTMENT SCREEN
// Last Updated: 2025-12-09 | Features: Assign ingredients to suppliers, Generate POs
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class AllotmentScreen extends StatefulWidget {
  final int mrpRunId;
  final String firmId;

  const AllotmentScreen({super.key, required this.mrpRunId, required this.firmId});

  @override
  State<AllotmentScreen> createState() => _AllotmentScreenState();
}

class _AllotmentScreenState extends State<AllotmentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _mrpOutput = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  
  // Track allocation: ingredientId -> supplierId
  final Map<int, int?> _allocations = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _mrpOutput = await DatabaseHelper().getMrpOutput(widget.mrpRunId);
    _suppliers = await DatabaseHelper().getAllSuppliers(widget.firmId);
    setState(() => _isLoading = false);
  }

  Future<void> _generatePOs() async {
    // Group allocations by supplier
    final supplierGroups = <int, List<Map<String, dynamic>>>{};
    
    for (var item in _mrpOutput) {
      final ingredientId = item['ingredientId'] as int;
      final supplierId = _allocations[ingredientId];
      
      if (supplierId != null) {
        supplierGroups.putIfAbsent(supplierId, () => []).add(item);
      }
    }

    if (supplierGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.allocateIngredientsFirst), backgroundColor: Colors.orange),
      );
      return;
    }

    // Create PO for each supplier
    for (var entry in supplierGroups.entries) {
      final supplierId = entry.key;
      final items = entry.value;
      final supplier = _suppliers.firstWhere((s) => s['id'] == supplierId, orElse: () => {});
      
      final poNumber = await DatabaseHelper().generatePoNumber(widget.firmId);
      final poId = await DatabaseHelper().createPurchaseOrder({
        'firmId': widget.firmId,
        'mrpRunId': widget.mrpRunId,
        'poNumber': poNumber,
        'type': 'SUPPLIER',
        'vendorId': supplierId,
        'vendorName': supplier['name'] ?? AppLocalizations.of(context)!.unknown,
        'totalItems': items.length,
        'status': 'SENT',
      });

      // Add PO items
      await DatabaseHelper().addPoItems(poId, items.map((i) => {
        'itemType': 'INGREDIENT',
        'itemId': i['ingredientId'],
        'itemName': i['ingredientName'],
        'quantity': i['requiredQty'],
        'unit': i['unit'],
      }).toList());
    }

    // Lock orders
    final db = await DatabaseHelper().database;
    final runOrders = await db.query('mrp_run_orders', where: 'mrpRunId = ?', whereArgs: [widget.mrpRunId]);
    final orderIds = runOrders.map((o) => o['orderId'] as int).toList();
    await DatabaseHelper().lockOrdersForMrp(widget.mrpRunId, orderIds);

    // Update MRP run status
    await db.update('mrp_runs', {'status': 'PO_SENT', 'completedAt': DateTime.now().toIso8601String()},
      where: 'id = ?', whereArgs: [widget.mrpRunId]);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.posGeneratedSuccess(supplierGroups.length)), 
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
    Navigator.pop(context); // Go back to MRP Run
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.allotmentTitle),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.supplierAllotment),
            Tab(text: AppLocalizations.of(context)!.summary),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSupplierTab(),
                _buildSummaryTab(),
              ],
            ),
    );
  }

  Widget _buildSupplierTab() {
    // Group by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var item in _mrpOutput) {
      final cat = item['category'] ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 8),
              Expanded(child: Text(AppLocalizations.of(context)!.assignIngredientHint)),
              Text(AppLocalizations.of(context)!.assignedStatus(_allocations.values.where((v) => v != null).length, _mrpOutput.length),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final category = grouped.keys.elementAt(index);
              final items = grouped[category]!;
              
              return ExpansionTile(
                title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(AppLocalizations.of(context)!.itemsCount(items.length)),
                initiallyExpanded: true,
                children: items.map((item) {
                  final ingredientId = item['ingredientId'] as int;
                  return ListTile(
                    title: Text(item['ingredientName'] ?? AppLocalizations.of(context)!.unknown),
                    subtitle: Text('${(item['requiredQty'] as num?)?.toStringAsFixed(2) ?? '0'} ${item['unit'] ?? 'kg'}'),
                    trailing: SizedBox(
                      width: 150,
                        child: DropdownButtonFormField<int>(
                        value: _allocations[ingredientId],
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.supplier,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          border: const OutlineInputBorder(),
                        ),
                        items: _suppliers.map((s) => DropdownMenuItem<int>(
                          value: s['id'],
                          child: Text(s['name'] ?? AppLocalizations.of(context)!.unknown, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) {
                          setState(() => _allocations[ingredientId] = v);
                        },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _generatePOs,
              icon: const Icon(Icons.send),
              label: Text(AppLocalizations.of(context)!.generateAndSendPos),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTab() {
    // Group allocations by supplier
    final supplierGroups = <int, List<Map<String, dynamic>>>{};
    for (var item in _mrpOutput) {
      final ingredientId = item['ingredientId'] as int;
      final supplierId = _allocations[ingredientId];
      if (supplierId != null) {
        supplierGroups.putIfAbsent(supplierId, () => []).add(item);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(AppLocalizations.of(context)!.posWillBeGenerated(supplierGroups.length), 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...supplierGroups.entries.map((entry) {
          final supplier = _suppliers.firstWhere((s) => s['id'] == entry.key, orElse: () => {});
          return Card(
            child: ExpansionTile(
              leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
              title: Text(supplier['name'] ?? AppLocalizations.of(context)!.unknown),
              subtitle: Text(AppLocalizations.of(context)!.itemsCount(entry.value.length)),
              children: entry.value.map((item) => ListTile(
                dense: true,
                title: Text(item['ingredientName'] ?? AppLocalizations.of(context)!.unknown),
                trailing: Text('${(item['requiredQty'] as num?)?.toStringAsFixed(2) ?? '0'} ${item['unit']}'),
              )).toList(),
            ),
          );
        }),
        if (supplierGroups.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.warning, size: 48, color: Colors.orange.shade300),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.noAllocationsMade),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
