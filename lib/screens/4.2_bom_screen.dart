// MODULE: BOM (Bill of Materials) MANAGEMENT
// Last Updated: 2025-12-09 | Features: Dish-Ingredient mapping @ 100 pax standard
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class BomScreen extends StatefulWidget {
  const BomScreen({super.key});

  @override
  State<BomScreen> createState() => _BomScreenState();
}

class _BomScreenState extends State<BomScreen> {
  List<Map<String, dynamic>> _dishes = [];
  bool _isLoading = true;
  String? _firmId;
  final _searchController = TextEditingController();

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
      _dishes = await DatabaseHelper().getAllDishes(_firmId!);
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _editBom(Map<String, dynamic> dish) async {
    final dishId = dish['id'] as int;
    final dishName = dish['name'] ?? 'Dish';
    
    // Get BOM for this dish (query now returns quantityPer100Pax directly)
    final bom = await DatabaseHelper().getBomForDish(_firmId!, dishId);
    final ingredients = await DatabaseHelper().getAllIngredients(_firmId!);
    
    // Add ingredientId mapping for UI
    final uiBom = bom.map((b) => {
      ...b,
      'ingredientId': b['ing_id'],
    }).toList();

    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => BomEditScreen(
        dishId: dishId,
        dishName: dishName,
        firmId: _firmId!,
        existingBom: uiBom,
        allIngredients: ingredients,
      ),
    ));
    
    // Refresh after return
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchController.text.isEmpty
        ? _dishes
        : _dishes.where((d) => 
            (d['name'] ?? '').toLowerCase().contains(_searchController.text.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.bomManagement),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Info Banner
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.bomInfo,
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          
          // Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchDishes,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          
          // Dish List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context)!.noDishesFound),
                            const SizedBox(height: 8),
                            Text(AppLocalizations.of(context)!.addDishesHint,
                              style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final dish = filtered[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: const Icon(Icons.restaurant, color: Colors.blue),
                              ),
                              title: Text(dish['name'] ?? AppLocalizations.of(context)!.unknown, 
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${AppLocalizations.of(context)!.category}: ${dish['category'] ?? AppLocalizations.of(context)!.na}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FutureBuilder<List<Map<String, dynamic>>>(
                                    future: DatabaseHelper().getBomForDish(_firmId!, dish['id']),
                                    builder: (context, snapshot) {
                                      final count = snapshot.data?.length ?? 0;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: count > 0 ? Colors.green.shade100 : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          AppLocalizations.of(context)!.itemsCount(count),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: count > 0 ? Colors.green.shade800 : Colors.orange.shade800,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () => _editBom(dish),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// --- BOM Edit Screen ---
class BomEditScreen extends StatefulWidget {
  final int dishId;
  final String dishName;
  final String firmId;
  final List<Map<String, dynamic>> existingBom;
  final List<Map<String, dynamic>> allIngredients;

  const BomEditScreen({
    super.key,
    required this.dishId,
    required this.dishName,
    required this.firmId,
    required this.existingBom,
    required this.allIngredients,
  });

  @override
  State<BomEditScreen> createState() => _BomEditScreenState();
}

class _BomEditScreenState extends State<BomEditScreen> {
  late List<Map<String, dynamic>> _bomItems;
  
  @override
  void initState() {
    super.initState();
    _bomItems = List.from(widget.existingBom);
  }

  Future<void> _addIngredient() async {
    // Filter out already added ingredients
    final addedIds = _bomItems.map((b) => b['ingredientId']).toSet();
    final available = widget.allIngredients.where((i) => !addedIds.contains(i['id'])).toList();
    
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.allIngredientsAdded), backgroundColor: Colors.orange),
      );
      return;
    }
    
    int? selectedId;
    final qtyController = TextEditingController();
    final searchController = TextEditingController();
    String searchQuery = '';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filter available ingredients based on search query
          final filteredIngredients = searchQuery.isEmpty
              ? available
              : available.where((i) => 
                  (i['name'] ?? '').toLowerCase().contains(searchQuery.toLowerCase()) ||
                  (i['category'] ?? '').toLowerCase().contains(searchQuery.toLowerCase())
                ).toList();
          
          // Find selected ingredient for display
          final selectedIng = selectedId != null 
              ? available.firstWhere((i) => i['id'] == selectedId, orElse: () => <String, dynamic>{})
              : null;
          
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.addIngredient),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search field
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchPlaceholder,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) => setDialogState(() => searchQuery = value),
                  ),
                  const SizedBox(height: 8),
                  
                  // Selected ingredient chip (if any)
                  if (selectedIng != null && selectedIng.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selectedIng['name']} (${selectedIng['unit_of_measure'] ?? 'kg'})',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setDialogState(() => selectedId = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  
                  // Ingredients list
                  Expanded(
                    child: filteredIngredients.isEmpty
                        ? Center(
                            child: Text(
                              AppLocalizations.of(context)!.noResultsFound,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredIngredients.length,
                            itemBuilder: (context, index) {
                              final ing = filteredIngredients[index];
                              final isSelected = selectedId == ing['id'];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isSelected ? Colors.green : Colors.grey.shade200,
                                  child: Icon(
                                    isSelected ? Icons.check : Icons.eco,
                                    size: 16,
                                    color: isSelected ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                                title: Text(
                                  ing['name'] ?? '',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.green.shade800 : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${ing['category'] ?? 'Other'} • ${ing['unit_of_measure'] ?? 'kg'}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                selected: isSelected,
                                selectedTileColor: Colors.green.shade50,
                                onTap: () => setDialogState(() => selectedId = ing['id']),
                              );
                            },
                          ),
                  ),
                  
                  const Divider(),
                  
                  // Quantity input
                  TextField(
                    controller: qtyController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.quantity100Pax,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.scale),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), 
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  if (selectedId == null || qtyController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.selectIngredientHint), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  
                  final ing = available.firstWhere((i) => i['id'] == selectedId);
                  await DatabaseHelper().insertBomItem({
                    'firmId': widget.firmId,
                    'dishId': widget.dishId,
                    'ingredientId': selectedId,
                    'quantityPer100Pax': double.parse(qtyController.text),
                    'unit': ing['unit_of_measure'],
                  });
                  Navigator.pop(context, true);
                },
                label: Text(AppLocalizations.of(context)!.add),
              ),
            ],
          );
        },
      ),
    );
    
    if (result == true) {
      // Reload BOM
      final updated = await DatabaseHelper().getBomForDish(widget.firmId, widget.dishId);
      setState(() => _bomItems = updated);
    }
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final qtyController = TextEditingController(
      text: (item['quantityPer100Pax'] ?? 0).toString(),
    );
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppLocalizations.of(context)!.editIngredient}: ${item['ingredientName'] ?? AppLocalizations.of(context)!.unknown}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${AppLocalizations.of(context)!.unit}: ${item['unit'] ?? 'kg'}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.quantity100Pax,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (qtyController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.enterQuantity), backgroundColor: Colors.red),
                );
                return;
              }
              
              try {
                final newQty = double.parse(qtyController.text);
                await DatabaseHelper().updateBomItem(item['id'] as int, {
                  'quantity_per_base_pax': newQty / 100, // Convert back to per-pax
                });
                Navigator.pop(context, true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.error(e.toString())), backgroundColor: Colors.red),
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
    
    if (result == true) {
      // Reload BOM
      final updated = await DatabaseHelper().getBomForDish(widget.firmId, widget.dishId);
      setState(() => _bomItems = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.quantityUpdated), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _deleteItem(int id) async {
    await DatabaseHelper().deleteBomItem(id);
    final updated = await DatabaseHelper().getBomForDish(widget.firmId, widget.dishId);
    setState(() => _bomItems = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.ingredientRemoved), backgroundColor: Colors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BOM: ${widget.dishName}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addIngredient,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.restaurant),
                const SizedBox(width: 8),
                Text(widget.dishName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(AppLocalizations.of(context)!.pax100, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          // BOM List
          Expanded(
            child: _bomItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(context)!.noIngredientsAdded),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _addIngredient,
                          icon: const Icon(Icons.add),
                          label: Text(AppLocalizations.of(context)!.addIngredient),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _bomItems.length,
                    itemBuilder: (context, index) {
                      final item = _bomItems[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(item['ingredientName'] ?? AppLocalizations.of(context)!.unknown),
                        subtitle: Text('${AppLocalizations.of(context)!.category}: ${item['category'] ?? AppLocalizations.of(context)!.na}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item['quantityPer100Pax']} ${item['unit']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editItem(item),
                              tooltip: 'Edit quantity',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(item['id']),
                              tooltip: 'Remove ingredient',
                            ),
                          ],
                        ),
                        onTap: () => _editItem(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
