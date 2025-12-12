// MODULE: MRP RUN SCREEN
// Last Updated: 2025-12-09 | Features: Order selection, Subcontractor assignment, MRP calculation
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '4.4_mrp_output_screen.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class MrpRunScreen extends StatefulWidget {
  const MrpRunScreen({super.key});

  @override
  State<MrpRunScreen> createState() => _MrpRunScreenState();
}

class _MrpRunScreenState extends State<MrpRunScreen> {
  bool _isLoading = true;
  bool _isCalculating = false;
  String? _firmId;
  
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _subcontractors = [];
  
  // Track selections: orderId -> {isSubcontracted, subcontractorId}
  final Map<int, Map<String, dynamic>> _orderSettings = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final sp = await SharedPreferences.getInstance();
    _firmId = sp.getString('last_firm');
    
    if (_firmId != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _orders = await DatabaseHelper().getOrdersByDate(dateStr);
      _subcontractors = await DatabaseHelper().getAllSubcontractors(_firmId!);
      
      // Initialize settings for each order
      for (var order in _orders) {
        final orderId = order['id'] as int;
        if (!_orderSettings.containsKey(orderId)) {
          _orderSettings[orderId] = {
            'isSubcontracted': false,
            'subcontractorId': null,
          };
        }
      }
    }
    
    setState(() => _isLoading = false);
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      _selectedDate = picked;
      _loadData();
    }
  }

  int get _totalPax {
    int total = 0;
    for (var order in _orders) {
      final orderId = order['id'] as int;
      if (!(_orderSettings[orderId]?['isSubcontracted'] ?? false)) {
        total += (order['pax'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  int get _liveKitchenOrders {
    return _orders.where((o) => !(_orderSettings[o['id']]?['isSubcontracted'] ?? false)).length;
  }

  int get _subcontractedOrders {
    return _orders.where((o) => _orderSettings[o['id']]?['isSubcontracted'] ?? false).length;
  }

  Future<void> _runMrp() async {
    if (_orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noOrdersToProcess), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isCalculating = true);

    try {
      // Create MRP Run
      final mrpRunId = await DatabaseHelper().createMrpRun({
        'firmId': _firmId,
        'runDate': DateTime.now().toIso8601String(),
        'targetDate': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'status': 'DRAFT',
        'totalOrders': _orders.length,
        'totalPax': _totalPax,
      });

      // Add orders to MRP run
      final orderRecords = _orders.map((o) {
        final orderId = o['id'] as int;
        return {
          'orderId': orderId,
          'pax': o['pax'] ?? 0,
          'isSubcontracted': _orderSettings[orderId]?['isSubcontracted'] == true ? 1 : 0,
          'subcontractorId': _orderSettings[orderId]?['subcontractorId'],
        };
      }).toList();
      await DatabaseHelper().addOrdersToMrpRun(mrpRunId, orderRecords);

      // Calculate ingredient requirements (only for live kitchen orders)
      final output = <int, Map<String, dynamic>>{}; // ingredientId -> {qty, unit, category}
      
      for (var order in _orders) {
        final orderId = order['id'] as int;
        if (_orderSettings[orderId]?['isSubcontracted'] == true) continue;
        
        final orderPax = (order['pax'] as num?)?.toInt() ?? 0;
        
        // Get dishes for this order
        final dishes = await DatabaseHelper().getDishesForOrder(orderId);
        
        for (var dish in dishes) {
          final dishId = dish['dishId'] as int?;
          if (dishId == null) continue;
          
          final dishQty = (dish['quantity'] as num?)?.toInt() ?? 1;
          
          // Get BOM for this dish
          final bom = await DatabaseHelper().getBomForDish(_firmId!, dishId);
          
          for (var bomItem in bom) {
            final ingredientId = bomItem['ingredientId'] as int;
            final qtyPer100 = (bomItem['quantityPer100Pax'] as num?)?.toDouble() ?? 0;
            final unit = bomItem['unit'] ?? 'kg';
            final category = bomItem['category'] ?? 'Other';
            
            // Calculate: (qty_per_100 / 100) * pax * dish_qty
            final required = (qtyPer100 / 100) * orderPax * dishQty;
            
            if (output.containsKey(ingredientId)) {
              output[ingredientId]!['requiredQty'] += required;
            } else {
              output[ingredientId] = {
                'ingredientId': ingredientId,
                'requiredQty': required,
                'unit': unit,
                'category': category,
              };
            }
          }
        }
      }

      // Save MRP output
      await DatabaseHelper().saveMrpOutput(mrpRunId, output.values.toList());

      setState(() => _isCalculating = false);

      // Navigate to output screen
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => MrpOutputScreen(mrpRunId: mrpRunId, firmId: _firmId!),
        ));
      }
    } catch (e) {
      setState(() => _isCalculating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.error(e.toString())), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.mrpRunScreenTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Date Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Spacer(),
                OutlinedButton(
                  onPressed: _selectDate,
                  child: Text(AppLocalizations.of(context)!.changeDate),
                ),
              ],
            ),
          ),
          
          // Summary Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _summaryCard(AppLocalizations.of(context)!.totalOrders, '${_orders.length}', Colors.blue),
                const SizedBox(width: 8),
                _summaryCard(AppLocalizations.of(context)!.liveKitchen, '$_liveKitchenOrders', Colors.green),
                const SizedBox(width: 8),
                _summaryCard(AppLocalizations.of(context)!.subcontracted, '$_subcontractedOrders', Colors.orange),
                const SizedBox(width: 8),
                _summaryCard('Total Pax', '$_totalPax', Colors.purple),
              ],
            ),
          ),
          
          // Order List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context)!.noOrdersForDate),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _selectDate,
                              child: Text(AppLocalizations.of(context)!.selectDifferentDate),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _orders.length,
                        itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
                      ),
          ),
          
          // Run MRP Button
          if (_orders.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isCalculating ? null : _runMrp,
                  icon: _isCalculating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.calculate),
                  label: Text(_isCalculating ? AppLocalizations.of(context)!.calculating : AppLocalizations.of(context)!.runMrp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
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

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id'] as int;
    final isSubcontracted = _orderSettings[orderId]?['isSubcontracted'] ?? false;
    final subcontractorId = _orderSettings[orderId]?['subcontractorId'];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('#${order['id']}', style: TextStyle(color: Colors.blue.shade800)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(order['customerName'] ?? 'Customer', 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text('${order['pax'] ?? 0} pax', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(order['venue'] ?? 'Venue not specified', style: TextStyle(color: Colors.grey.shade600)),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Live Kitchen'),
                    selected: !isSubcontracted,
                    onSelected: (v) {
                      setState(() {
                        _orderSettings[orderId] = {
                          'isSubcontracted': false,
                          'subcontractorId': null,
                        };
                      });
                    },
                    selectedColor: Colors.green.shade100,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Subcontract'),
                    selected: isSubcontracted,
                    onSelected: (v) {
                      setState(() {
                        _orderSettings[orderId] = {
                          'isSubcontracted': true,
                          'subcontractorId': null,
                        };
                      });
                    },
                    selectedColor: Colors.orange.shade100,
                  ),
                ),
              ],
            ),
            if (isSubcontracted) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: subcontractorId,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.selectSubcontractor,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _subcontractors.map((s) => DropdownMenuItem<int>(
                  value: s['id'],
                  child: Text(s['name'] ?? AppLocalizations.of(context)!.unknown),
                )).toList(),
                onChanged: (v) {
                  setState(() {
                    _orderSettings[orderId]?['subcontractorId'] = v;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
