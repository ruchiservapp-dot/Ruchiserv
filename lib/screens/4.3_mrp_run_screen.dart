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

class _MrpRunScreenState extends State<MrpRunScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isCalculating = false;
  String? _firmId;
  late TabController _tabController;
  
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _orders = []; // Pending orders (selectable)
  List<Map<String, dynamic>> _processedOrders = []; // Already processed (read-only)
  List<Map<String, dynamic>> _subcontractors = [];
  
  Map<int, List<Map<String, dynamic>>> _orderDishes = {}; // orderId -> List<Dish>

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
    final sp = await SharedPreferences.getInstance();
    _firmId = sp.getString('last_firm');
    
    if (_firmId != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // STRICT: Only fetch PENDING orders for MRP selection
      _orders = await DatabaseHelper().getPendingOrdersForMrp(dateStr);
      // Also fetch processed orders for read-only display
      _processedOrders = await DatabaseHelper().getProcessedOrdersForMrp(dateStr);
      
      _subcontractors = await DatabaseHelper().getAllSubcontractors(_firmId!);
      
      // Load dishes for pending orders only
      _orderDishes.clear();
      for (var order in _orders) {
        final orderId = order['id'] as int;
        final dishes = await DatabaseHelper().getDishesForOrder(orderId);
        // Make mutable copy and init excluded set
        _orderDishes[orderId] = dishes.map((d) {
           final map = Map<String, dynamic>.from(d);
           map['excludedIngredientIds'] = <int>{}; // Initialize set
           return map;
        }).toList();
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
      total += (order['totalPax'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  Future<void> _runMrp() async {
    if (_orders.isEmpty) return;

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
        return {
          'orderId': o['id'],
          'pax': o['totalPax'] ?? 0,
          'isSubcontracted': 0, // Legacy/Full order toggle removed
          'subcontractorId': null,
        };
      }).toList();
      await DatabaseHelper().addOrdersToMrpRun(mrpRunId, orderRecords);

      // Calculate ingredient requirements
      final output = <int, Map<String, dynamic>>{}; 
      
      print('📊 [MRP] Starting ingredient calculation for ${_orders.length} orders');
      
      for (var order in _orders) {
        final orderId = order['id'] as int;
        final dishes = _orderDishes[orderId] ?? [];
        
        for (var dish in dishes) {
          // SKIP SUBCONTRACTED DISHES (Use productionType as truth)
          if (dish['productionType'] == 'SUBCONTRACT') {
            print('📊 [MRP] Skipping subcontracted dish: ${dish['name']}');
            continue;
          }

          final dishName = dish['name'] as String?;
          if (dishName == null || dishName.isEmpty) continue;
          
          final dishQty = (dish['pax'] as num?)?.toInt() ?? 1;
          final excludedIds = dish['excludedIngredientIds'] as Set<int>? ?? {};
          
          // Look up BOM
          final bom = await DatabaseHelper().getRecipeForDishByName(dishName, dishQty);
          
          for (var bomItem in bom) {
            final ingredientId = bomItem['ing_id'] as int?;
            if (ingredientId == null) continue;
            
            // Check exclusion
            if (excludedIds.contains(ingredientId)) {
               print('❌ [MRP] Skipping excluded ingredient ID: $ingredientId for dish: $dishName');
               continue;
            }
            
            final scaledQty = (bomItem['scaledQuantity'] as num?)?.toDouble() ?? 0;
            final unit = bomItem['unit'] ?? 'kg';
            final category = bomItem['category'] ?? 'Other';
            
            if (output.containsKey(ingredientId)) {
              output[ingredientId]!['requiredQty'] += scaledQty;
            } else {
              output[ingredientId] = {
                'ingredientId': ingredientId,
                'requiredQty': scaledQty,
                'unit': unit,
                'category': category,
              };
            }
          }
        }
      }
      
      // Save output
      await DatabaseHelper().saveMrpOutput(mrpRunId, output.values.toList());

      // Lock Orders (implied partial lock or full lock? Legacy method locks full order)
      // We should probably still mark orders as part of this run.
      await DatabaseHelper().lockOrdersForMrp(mrpRunId, _orders.map((o) => o['id'] as int).toList());

      setState(() => _isCalculating = false);

      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => MrpOutputScreen(mrpRunId: mrpRunId, firmId: _firmId!),
        ));
      }
    } catch (e) {
      setState(() => _isCalculating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  Future<void> _toggleDishSubcontract(int orderId, int index, bool val) async {
    final dish = _orderDishes[orderId]![index];
    final dishId = dish['id'] as int;
    
    // Check lock via UI state first (optimistic)
    // Actually DB check inside helper is safer
    
    final success = await DatabaseHelper().toggleDishSubcontract(dishId, val);
    if (success) {
      setState(() {
        dish['isSubcontracted'] = val ? 1 : 0;
        dish['productionType'] = val ? 'SUBCONTRACT' : 'INTERNAL';
      });
    } else {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot change: Order is locked/finalized.'), backgroundColor: Colors.orange),
        );
       }
    }
  }

  void _showIngredients(int orderId, int dishIndex) async {
    final dish = _orderDishes[orderId]![dishIndex];
    final dishName = dish['name'] as String;
    final pax = (dish['pax'] as num?)?.toInt() ?? 0;
    
    // Fetch ingredients for this dish
    final ingredients = await DatabaseHelper().getRecipeForDishByName(dishName, pax);
    final excludedIds = dish['excludedIngredientIds'] as Set<int>;
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            double totalCost = 0;
            // Calculate cost OF INCLUDED ITEMS ONLY
            for (var i in ingredients) {
              final id = i['ing_id'] as int;
              if (!excludedIds.contains(id)) {
                final qty = (i['scaledQuantity'] as num?)?.toDouble() ?? 0;
                final rate = (i['cost_per_unit'] as num?)?.toDouble() ?? 0;
                totalCost += (qty * rate);
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.restaurant, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text(dishName, style: const TextStyle(fontSize: 16))),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ingredients.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)!.noIngredientsAdded,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.group, size: 16, color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Text('$pax pax', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                  ],
                                ),
                                Text('Est. Cost: ₹${totalCost.toStringAsFixed(2)}', 
                                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(AppLocalizations.of(context)!.ingredientsRequired, 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: ingredients.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final ing = ingredients[index];
                                final id = ing['ing_id'] as int;
                                final name = ing['ingredientName'] ?? 'Unknown';
                                final qty = (ing['scaledQuantity'] as num?)?.toStringAsFixed(2) ?? '0';
                                final unit = ing['unit'] ?? 'kg';
                                // Cost calculation
                                final rate = (ing['cost_per_unit'] as num?)?.toDouble() ?? 0;
                                final amount = ((ing['scaledQuantity'] as num?)?.toDouble() ?? 0) * rate;
                                
                                final isIncluded = !excludedIds.contains(id);

                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  activeColor: Colors.green,
                                  value: isIncluded,
                                  onChanged: (val) {
                                     setDialogState(() {
                                        if (val == true) {
                                          excludedIds.remove(id);
                                        } else {
                                          excludedIds.add(id);
                                        }
                                     });
                                     // Also update parent set if needed, but it's passed by reference so it updates directly
                                  },
                                  title: Text(name, style: TextStyle(
                                     fontSize: 13, 
                                     color: isIncluded ? Colors.black : Colors.grey,
                                     decoration: isIncluded ? null : TextDecoration.lineThrough
                                  )),
                                  subtitle: Text('Rate: ₹${rate.toStringAsFixed(2)} / $unit', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                  secondary: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isIncluded ? Colors.black : Colors.grey)),
                                      Text('$qty $unit', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.ok),
                ),
              ],
            );
          }
        );
      }
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
    final dishes = _orderDishes[orderId] ?? [];
    
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
                Text('${order['totalPax'] ?? 0} pax', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(order['venue'] ?? AppLocalizations.of(context)!.venueNotSpecified, style: TextStyle(color: Colors.grey.shade600)),
            
            const SizedBox(height: 12),
            const Text('Dishes Configuration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: dishes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final dish = dishes[index];
                // Check productionType for truth
                final isSub = dish['productionType'] == 'SUBCONTRACT';
                final name = dish['name'] ?? 'Unknown';
                final pax = dish['pax'] ?? 0;
                
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: DatabaseHelper().getRecipeForDishByName(name, pax),
                  builder: (context, bomSnapshot) {
                    final hasIngredients = (bomSnapshot.data?.isNotEmpty ?? false);
                    final ingredientCount = bomSnapshot.data?.length ?? 0;
                    
                    return InkWell(
                      onTap: () => _showIngredients(orderId, index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSub ? Colors.purple.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSub 
                                ? Colors.purple.shade100 
                                : (hasIngredients ? Colors.green.shade200 : Colors.red.shade300),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Validation Icon (Only relevant if not subcontracted?)
                            // User wants to see validation regardless
                             Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: hasIngredients ? Colors.green.shade50 : Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  hasIngredients ? Icons.check_circle : Icons.warning_rounded,
                                  size: 16,
                                  color: hasIngredients ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                             const SizedBox(width: 8),
                             
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(name, style: TextStyle(
                                     fontWeight: FontWeight.w500,
                                     decoration: isSub ? TextDecoration.lineThrough : null,
                                     color: isSub ? Colors.grey : Colors.black
                                   )),
                                   Row(
                                     children: [
                                       Text('Qty: $pax', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                       const SizedBox(width: 8),
                                       if (hasIngredients)
                                         Text('$ingredientCount items', style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold))
                                       else
                                         Text('No BOM', style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                     ],
                                   ),
                                 ],
                               ),
                             ),
                             
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.end,
                               children: [
                                 Text(isSub ? 'Subcontract' : 'In-House', 
                                    style: TextStyle(fontSize: 10, color: isSub ? Colors.purple : Colors.green, fontWeight: FontWeight.bold)),
                                 Switch(
                                   value: !isSub, // True = In-House (Include in MRP)
                                   activeColor: Colors.green,
                                   inactiveThumbColor: Colors.purple,
                                   trackColor: MaterialStateProperty.resolveWith((states) => isSub ? Colors.purple.shade100 : Colors.green.shade100),
                                   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                   onChanged: (val) {
                                      // val=true -> InHouse -> isSub=false
                                      _toggleDishSubcontract(orderId, index, !val);
                                   },
                                 ),
                               ],
                             ),
                          ],
                        ),
                      ),
                    );
                  }
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.mrpRunScreenTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Pending (${_orders.length})'),
            Tab(text: 'Processed (${_processedOrders.length})'),
          ],
        ),
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
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton(
                  onPressed: _selectDate,
                  child: Text(AppLocalizations.of(context)!.changeDate),
                ),
              ],
            ),
          ),
          
          // Summary Cards (only for Pending tab)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _summaryCard('Pending', '${_orders.length}', Colors.orange),
                const SizedBox(width: 8),
                _summaryCard('Processed', '${_processedOrders.length}', Colors.green),
                const SizedBox(width: 8),
                _summaryCard('Total Pax', '$_totalPax', Colors.purple),
              ],
            ),
          ),
          
          // Tabbed Order List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: Pending Orders (Selectable)
                      _orders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
                                  const SizedBox(height: 16),
                                  const Text('All orders processed!', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text('No pending orders for this date.', style: TextStyle(color: Colors.grey.shade600)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _orders.length,
                              itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
                            ),
                      
                      // TAB 2: Processed Orders (Read-only)
                      _processedOrders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.pending_actions, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  const Text('No processed orders yet'),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _processedOrders.length,
                              itemBuilder: (context, index) => _buildProcessedOrderCard(_processedOrders[index]),
                            ),
                    ],
                  ),
          ),
          
          // Run MRP Button (only visible when on Pending tab with orders)
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

  // Helper widget for processed orders (read-only display)
  Widget _buildProcessedOrderCard(Map<String, dynamic> order) {
    final mrpStatus = order['mrpStatus'] ?? 'PROCESSED';
    final statusColor = mrpStatus == 'PO_SENT' ? Colors.green : Colors.blue;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('#${order['id']}', style: TextStyle(color: statusColor)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order['customerName'] ?? 'Customer', 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${order['totalPax'] ?? 0} pax', 
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                mrpStatus.toString().replaceAll('_', ' '),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
