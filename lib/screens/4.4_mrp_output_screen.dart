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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _output = await DatabaseHelper().getMrpOutput(widget.mrpRunId);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Group by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var item in _output) {
      final cat = item['category'] ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

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
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text('MRP Run #${widget.mrpRunId}', 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(AppLocalizations.of(context)!.ingredientsCount(_output.length),
                  style: TextStyle(color: Colors.grey.shade600)),
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
                          
                          return ExpansionTile(
                            title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(AppLocalizations.of(context)!.itemsCount(items.length)),
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
                            children: items.map((item) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getCategoryColor(category).withOpacity(0.2),
                                child: Text(item['ingredientName']?[0]?.toUpperCase() ?? '?',
                                  style: TextStyle(color: _getCategoryColor(category))),
                              ),
                              title: Text(item['ingredientName'] ?? AppLocalizations.of(context)!.unknown),
                              trailing: Text(
                                '${(item['requiredQty'] as num?)?.toStringAsFixed(2) ?? '0'} ${item['unit'] ?? 'kg'}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            )).toList(),
                          );
                        },
                      ),
          ),
          
          // Proceed to Allotment
          if (_output.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AllotmentScreen(
                        mrpRunId: widget.mrpRunId,
                        firmId: widget.firmId,
                      ),
                    ));
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
