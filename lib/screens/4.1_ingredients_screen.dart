// MODULE: INGREDIENTS MASTER
// Last Updated: 2025-12-09 | Features: Pre-loaded ingredients list, Add/Edit, Categories
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../services/language_service.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class IngredientsScreen extends StatefulWidget {
  const IngredientsScreen({super.key});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _filteredIngredients = [];
  bool _isLoading = true;
  String? _firmId;
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'All', 'Vegetable', 'Meat', 'Seafood', 'Spice', 'Dairy', 
    'Grain', 'Oil', 'Beverage', 'Other'
  ];

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
      _ingredients = await DatabaseHelper().getAllIngredients(_firmId!);
      _applyFilter();
    }
    
    setState(() => _isLoading = false);
  }

  void _applyFilter() {
    setState(() {
      _filteredIngredients = _ingredients.where((ing) {
        final matchesCategory = _selectedCategory == 'All' || 
            ing['category'] == _selectedCategory;
        final matchesSearch = _searchController.text.isEmpty ||
            (ing['name'] ?? '').toLowerCase().contains(_searchController.text.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  Future<void> _addIngredient() async {
    final nameController = TextEditingController();
    final costController = TextEditingController(); // Added for V19
    final skuController = TextEditingController(); // Added for V19
    String category = 'Vegetable';
    String unit = 'kg';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.addIngredient),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.ingredientName,
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: skuController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.skuBrandOptional,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.costPerUnit,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.category,
                    border: const OutlineInputBorder(),
                  ),
                  items: _categories.where((c) => c != 'All').map((c) => 
                    DropdownMenuItem(value: c, child: Text(c))
                  ).toList(),
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.unit,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'kg', child: Text(AppLocalizations.of(context)!.unitKg)),
                    DropdownMenuItem(value: 'g', child: Text(AppLocalizations.of(context)!.unitG)),
                    DropdownMenuItem(value: 'liter', child: Text(AppLocalizations.of(context)!.unitL)),
                    DropdownMenuItem(value: 'ml', child: Text(AppLocalizations.of(context)!.unitMl)),
                    DropdownMenuItem(value: 'nos', child: Text(AppLocalizations.of(context)!.unitNos)),
                    DropdownMenuItem(value: 'bunch', child: Text(AppLocalizations.of(context)!.unitBunch)),
                  ],
                  onChanged: (v) => setDialogState(() => unit = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.cancel)),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.enterIngredientName), backgroundColor: Colors.red),
                  );
                  return;
                }
                try {
                  await DatabaseHelper().insertIngredient({
                    // Note: ingredients_master table is global (no firmId column)
                    'name': nameController.text.trim(),
                    'sku_name': skuController.text.trim().isEmpty ? null : skuController.text.trim(),
                    'cost_per_unit': double.tryParse(costController.text) ?? 0.0,
                    'category': category,
                    'unit_of_measure': unit,
                  });
                  Navigator.pop(context, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.error(e.toString())), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(AppLocalizations.of(context)!.add),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.ingredientAdded), backgroundColor: Colors.green),
      );
      _loadData();
    }
  }

  Future<void> _editIngredient(Map<String, dynamic> ingredient) async {
    final nameController = TextEditingController(text: ingredient['name'] ?? '');
    final costController = TextEditingController(text: (ingredient['cost_per_unit'] ?? 0).toString());
    final skuController = TextEditingController(text: ingredient['sku_name'] ?? '');
    String category = ingredient['category'] ?? 'Vegetable';
    
    // Normalize unit from database (may be uppercase like 'LITRE', 'KG', etc.)
    final dbUnit = (ingredient['unit_of_measure'] ?? 'kg').toString().toLowerCase();
    final validUnits = ['kg', 'g', 'liter', 'litre', 'ml', 'nos', 'bunch', 'pcs'];
    String unit = validUnits.contains(dbUnit) ? dbUnit : 'kg';
    // Map 'litre' to 'liter' for consistency
    if (unit == 'litre') unit = 'liter';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.editIngredient),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.ingredientName,
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: skuController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.skuBrandOptional,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.costPerUnit,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _categories.contains(category) && category != 'All' ? category : 'Vegetable',
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.category,
                    border: const OutlineInputBorder(),
                  ),
                  items: _categories.where((c) => c != 'All').map((c) => 
                    DropdownMenuItem(value: c, child: Text(c))
                  ).toList(),
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.unit,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'kg', child: Text(AppLocalizations.of(context)!.unitKg)),
                    DropdownMenuItem(value: 'g', child: Text(AppLocalizations.of(context)!.unitG)),
                    DropdownMenuItem(value: 'liter', child: Text(AppLocalizations.of(context)!.unitL)),
                    DropdownMenuItem(value: 'ml', child: Text(AppLocalizations.of(context)!.unitMl)),
                    DropdownMenuItem(value: 'nos', child: Text(AppLocalizations.of(context)!.unitNos)),
                    DropdownMenuItem(value: 'pcs', child: Text(AppLocalizations.of(context)!.unitPcs)),
                    DropdownMenuItem(value: 'bunch', child: Text(AppLocalizations.of(context)!.unitBunch)),
                  ],
                  onChanged: (v) => setDialogState(() => unit = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.cancel)),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.enterIngredientName), backgroundColor: Colors.red),
                  );
                  return;
                }
                try {
                  await DatabaseHelper().updateIngredient(ingredient['id'] as int, {
                    'name': nameController.text.trim(),
                    'sku_name': skuController.text.trim().isEmpty ? null : skuController.text.trim(),
                    'cost_per_unit': double.tryParse(costController.text) ?? 0.0,
                    'category': category,
                    'unit_of_measure': unit,
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
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.ingredientUpdated), backgroundColor: Colors.green),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group by category for display
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var ing in _filteredIngredients) {
      final cat = ing['category'] ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(ing);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.ingredientsMaster),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addIngredient,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search & Filter
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchPlaceholder,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (_) => _applyFilter(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _categories.map((c) => 
                      DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))
                    ).toList(),
                    onChanged: (v) {
                      _selectedCategory = v!;
                      _applyFilter();
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(AppLocalizations.of(context)!.ingredientsCount(_filteredIngredients.length), 
                  style: TextStyle(color: Colors.grey.shade600)),
                const Spacer(),
                Text(AppLocalizations.of(context)!.categoriesCount(grouped.keys.length),
                  style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredIngredients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context)!.noIngredientsFound),
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
                        itemCount: grouped.keys.length,
                        itemBuilder: (context, index) {
                          final category = grouped.keys.elementAt(index);
                          final items = grouped[category]!;
                          return ExpansionTile(
                            title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${items.length} items'),
                            initiallyExpanded: true,
                            children: items.map((ing) {
                                final localizedName = LanguageService().getLocalizedName(
                                  entityType: 'INGREDIENT',
                                  entityId: ing['id'] as int,
                                  defaultName: ing['name']?.toString() ?? 'Unknown',
                                );
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getCategoryColor(category),
                                    child: Text(localizedName.isNotEmpty ? localizedName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white)),
                                  ),
                                  title: Text(localizedName),
                                  subtitle: Text(
                                    '${ing['name']} | Unit: ${ing['unit_of_measure'] ?? 'kg'} | Cost: ₹${ing['cost_per_unit'] ?? 0}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _editIngredient(ing),
                                );
                            }).toList(),
                          );
                        },
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
