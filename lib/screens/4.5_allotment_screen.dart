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
  List<Map<String, dynamic>> _releasedPOs = []; // POs already generated for this MRP run
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
    
    // Use new method that filters out already PO'd items
    _mrpOutput = await DatabaseHelper().getMrpOutputForAllotment(widget.mrpRunId);
    _suppliers = await DatabaseHelper().getAllSuppliers(widget.firmId);
    
    // Load already-released POs for this MRP run (for Summary tab)
    _releasedPOs = await DatabaseHelper().getPurchaseOrdersByMrpRun(widget.mrpRunId);
    
    // Restore existing allocations from database
    final existingAllocations = await DatabaseHelper().getExistingAllocations(widget.mrpRunId);
    _allocations.clear();
    _allocations.addAll(existingAllocations);
    
    setState(() => _isLoading = false);
  }

  Future<void> _generatePOs() async {
    try {
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
        
        // Calculate total amount for this PO
        double totalAmount = 0;
        for (var i in items) {
          final rate = (i['rate'] as num?)?.toDouble() ?? 0;
          final qty = (i['requiredQty'] as num?)?.toDouble() ?? 0;
          totalAmount += rate * qty;
        }
        
        final poNumber = await DatabaseHelper().generatePoNumber(widget.firmId);
        final poId = await DatabaseHelper().createPurchaseOrder({
          'firmId': widget.firmId,
          'mrpRunId': widget.mrpRunId,
          'poNumber': poNumber,
          'type': 'SUPPLIER',
          'vendorId': supplierId,
          'vendorName': supplier['name'] ?? AppLocalizations.of(context)!.unknown,
          'totalItems': items.length,
          'totalAmount': totalAmount,
          'status': 'SENT',
        });

        // Add PO items with rate and amount
        await DatabaseHelper().addPoItems(poId, items.map((i) {
          final rate = (i['rate'] as num?)?.toDouble() ?? 0;
          final qty = (i['requiredQty'] as num?)?.toDouble() ?? 0;
          return {
            'itemId': i['ingredientId'],
            'itemName': i['ingredientName'],
            'quantity': qty,
            'unit': i['unit'] ?? 'kg',
            'rate': rate,
            'amount': rate * qty,
          };
        }).toList());
        
        // Mark MRP output items as PO_SENT to prevent re-processing
        final ingredientIds = items.map((i) => i['ingredientId'] as int).toList();
        await DatabaseHelper().markMrpOutputAsPOSent(widget.mrpRunId, poId, ingredientIds);
      }

      // Check if ALL items are now PO'd - only then update order/run status
      await DatabaseHelper().updateOrderStatusIfAllItemsPOd(widget.mrpRunId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.posGeneratedSuccess(supplierGroups.length)), 
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload data to show remaining items (if any)
        await _loadData();
        
        // If no more items to allocate, go back
        if (_mrpOutput.isEmpty) {
          Navigator.pop(context);
          Navigator.pop(context); // Go back to MRP Run
        }
      }
    } catch (e) {
      print('ERROR Generating POs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating POs: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
              // Only count allocations for items still showing (not PO'd)
              Builder(builder: (context) {
                final currentIngredientIds = _mrpOutput.map((i) => i['ingredientId'] as int).toSet();
                final allocatedCount = _allocations.entries
                    .where((e) => e.value != null && currentIngredientIds.contains(e.key))
                    .length;
                return Text(AppLocalizations.of(context)!.assignedStatus(allocatedCount, _mrpOutput.length),
                  style: const TextStyle(fontWeight: FontWeight.bold));
              }),
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
                        width: 130, // Reduced slightly to fit better
                        child: DropdownButtonFormField<int>(
                          isExpanded: true, // Fix: Prevent overflow by truncating text
                          value: _allocations[ingredientId],
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.supplier,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4), // Reduced padding
                            border: const OutlineInputBorder(),
                          ),
                          items: _suppliers.map((s) => DropdownMenuItem<int>(
                            value: s['id'],
                            child: Text(s['name'] ?? AppLocalizations.of(context)!.unknown, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) async {
                            setState(() => _allocations[ingredientId] = v);
                            // Persist allocation immediately to database
                            await DatabaseHelper().updateMrpOutputAllocations(
                              widget.mrpRunId, 
                              {ingredientId: v},
                            );
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
    // Group pending allocations by supplier (items still to be PO'd)
    final pendingGroups = <int, List<Map<String, dynamic>>>{};
    for (var item in _mrpOutput) {
      final ingredientId = item['ingredientId'] as int;
      final supplierId = _allocations[ingredientId];
      if (supplierId != null) {
        pendingGroups.putIfAbsent(supplierId, () => []).add(item);
      }
    }

    final hasPending = pendingGroups.isNotEmpty;
    final hasReleased = _releasedPOs.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section 1: Pending Allocations (items ready to generate POs)
        if (hasPending) ...[
          Text(AppLocalizations.of(context)!.posWillBeGenerated(pendingGroups.length), 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...pendingGroups.entries.map((entry) {
            final supplier = _suppliers.firstWhere((s) => s['id'] == entry.key, orElse: () => {});
            return Card(
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(Icons.pending_actions, color: Colors.orange.shade700),
                ),
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
          if (hasReleased) const SizedBox(height: 24),
        ],

        // Section 2: Already Released POs
        if (hasReleased) ...[
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
              const SizedBox(width: 8),
              Text('${_releasedPOs.length} POs Released', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            ],
          ),
          const SizedBox(height: 16),
          ..._releasedPOs.map((po) => Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Icon(Icons.receipt_long, color: Colors.green.shade700),
              ),
              title: Text(po['poNumber'] ?? 'PO', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(po['vendorName'] ?? AppLocalizations.of(context)!.unknown),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(po['status'] ?? 'SENT',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                  ),
                  Text(AppLocalizations.of(context)!.itemsCount(po['totalItems'] ?? 0),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              onTap: () => _viewPoDetails(po),
            ),
          )),
        ],

        // Empty state: no pending and no released
        if (!hasPending && !hasReleased)
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

  Future<void> _viewPoDetails(Map<String, dynamic> po) async {
    final items = await DatabaseHelper().getPoItems(po['id']);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(po['poNumber'] ?? 'PO', 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(po['status'] ?? 'SENT',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(po['vendorName'] ?? AppLocalizations.of(context)!.unknown, 
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)!.itemsCount(po['totalItems'] ?? 0), 
                        style: TextStyle(color: Colors.grey.shade600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${((po['totalAmount'] as num?) ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final rate = (item['rate'] as num?)?.toDouble() ?? 0;
                  final amount = (item['amount'] as num?)?.toDouble() ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(item['itemName'] ?? AppLocalizations.of(context)!.unknown),
                    subtitle: Text(
                      '${item['quantity']} ${item['unit'] ?? 'kg'} × ₹${rate.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    trailing: Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
