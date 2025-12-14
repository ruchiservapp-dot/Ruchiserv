// MODULE: MRP OUTPUT SCREEN
// Last Updated: 2025-12-09 | Features: View calculated ingredients by category
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '4.5_allotment_screen.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class MrpOutputScreen extends StatefulWidget {
  final int mrpRunId;
  final String firmId;

  const MrpOutputScreen({super.key, required this.mrpRunId, required this.firmId});

  @override
  State<MrpOutputScreen> createState() => _MrpOutputScreenState();
}

class _MrpOutputScreenState extends State<MrpOutputScreen> {
  List<Map<String, dynamic>> _output = [];
  Map<String, dynamic>? _runInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _output = await DatabaseHelper().getMrpOutput(widget.mrpRunId);
    
    // Load run info to get runName
    final db = await DatabaseHelper().database;
    final runs = await db.query('mrp_runs', where: 'id = ?', whereArgs: [widget.mrpRunId]);
    if (runs.isNotEmpty) {
      _runInfo = runs.first;
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Group by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    double grandTotal = 0;
    
    for (var item in _output) {
      final cat = item['category'] ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(item);
      grandTotal += (item['totalCost'] as num? ?? 0).toDouble();
    }
    
    // Get display name for run
    final runDisplayName = _runInfo?['runName'] ?? 'Run #${widget.mrpRunId}';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.mrpOutputTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('MRP $runDisplayName', 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(AppLocalizations.of(context)!.ingredientsCount(_output.length),
                      style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Est. Total Cost:', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      '₹${grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Output List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _output.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning, size: 64, color: Colors.orange.shade400),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context)!.noIngredientsCalculated),
                            const SizedBox(height: 8),
                            Text(AppLocalizations.of(context)!.checkBomDefined,
                              style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: grouped.keys.length,
                        itemBuilder: (context, index) {
                          final category = grouped.keys.elementAt(index);
                          final items = grouped[category]!;
                          final totalQty = items.fold<double>(0, (sum, i) => sum + (i['requiredQty'] ?? 0));
                          final totalCatCost = items.fold<double>(0, (sum, i) => sum + (i['totalCost'] ?? 0));
                          
                          return ExpansionTile(
                            title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${AppLocalizations.of(context)!.itemsCount(items.length)} • ₹${totalCatCost.toStringAsFixed(0)}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(category).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${totalQty.toStringAsFixed(1)} ${AppLocalizations.of(context)!.total}',
                                style: TextStyle(color: _getCategoryColor(category), fontWeight: FontWeight.bold),
                              ),
                            ),
                            initiallyExpanded: true,
                            children: items.map((item) {
                                final qty = (item['requiredQty'] as num?)?.toDouble() ?? 0;
                                final rate = (item['rate'] as num?)?.toDouble() ?? 0;
                                final cost = (item['totalCost'] as num?)?.toDouble() ?? 0;
                                final unit = item['unit'] ?? 'kg';
                                final allocationStatus = item['allocationStatus'] ?? 'PENDING';
                                final supplierName = item['supplierName'];

                                // Status color coding
                                Color statusColor;
                                IconData statusIcon;
                                String statusText;
                                switch (allocationStatus) {
                                  case 'ALLOCATED':
                                    statusColor = Colors.blue;
                                    statusIcon = Icons.assignment_turned_in;
                                    statusText = 'Allocated';
                                    break;
                                  case 'PO_SENT':
                                    statusColor = Colors.green;
                                    statusIcon = Icons.check_circle;
                                    statusText = 'PO Sent';
                                    break;
                                  default: // PENDING
                                    statusColor = Colors.orange;
                                    statusIcon = Icons.pending;
                                    statusText = 'Pending';
                                }

                                return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withOpacity(0.2),
                                  child: Icon(statusIcon, color: statusColor, size: 20),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(item['ingredientName'] ?? AppLocalizations.of(context)!.unknown)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(statusText, 
                                        style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${qty.toStringAsFixed(2)} $unit x ₹${rate.toStringAsFixed(2)}',
                                      style: TextStyle(color: Colors.grey.shade700),
                                    ),
                                    if (supplierName != null)
                                      Text('→ $supplierName', 
                                        style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                trailing: Text(
                                  '₹${cost.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
          ),
          
          // Bottom Summary & Action
          if (_output.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
              ),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Grand Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '₹${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AllotmentScreen(
                            mrpRunId: widget.mrpRunId,
                            firmId: widget.firmId,
                          ),
                        )).then((_) => _loadData()); // Refresh on return
                      },
                      icon: const Icon(Icons.assignment),
                      label: Text(AppLocalizations.of(context)!.proceedToAllotment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Vegetable': return Colors.green;
      case 'Meat': return Colors.red;
      case 'Seafood': return Colors.blue;
      case 'Spice': return Colors.orange;
      case 'Dairy': return Colors.amber;
      case 'Grain': return Colors.brown;
      case 'Oil': return Colors.yellow.shade700;
      case 'Beverage': return Colors.purple;
      default: return Colors.grey;
    }
  }
}
