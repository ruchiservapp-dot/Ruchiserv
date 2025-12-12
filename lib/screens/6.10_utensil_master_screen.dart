// MODULE: UTENSIL MASTER (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-07 | Features: Pre-populated Utensils, Category Grouping, Returnable/Consumable Classification
import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class UtensilMasterScreen extends StatefulWidget {
  const UtensilMasterScreen({super.key});

  @override
  State<UtensilMasterScreen> createState() => _UtensilMasterScreenState();
}

class _UtensilMasterScreenState extends State<UtensilMasterScreen> {
  List<Map<String, dynamic>> _utensils = [];
  bool _isLoading = true;
  bool _seeded = false;

  // Pre-populated common utensils for catering
  static const List<Map<String, String>> _defaultUtensils = [
    // Serving
    {'name': 'Serving Spoon (Large)', 'category': 'SERVING', 'isReturnable': '1'},
    {'name': 'Serving Spoon (Small)', 'category': 'SERVING', 'isReturnable': '1'},
    {'name': 'Ladle', 'category': 'SERVING', 'isReturnable': '1'},
    {'name': 'Chafing Dish', 'category': 'SERVING', 'isReturnable': '1'},
    {'name': 'Serving Bowl (Steel)', 'category': 'SERVING', 'isReturnable': '1'},
    {'name': 'Serving Tray', 'category': 'SERVING', 'isReturnable': '1'},
    {'name': 'Rice Pot', 'category': 'SERVING', 'isReturnable': '1'},
    // Cutlery
    {'name': 'Fork', 'category': 'CUTLERY', 'isReturnable': '1'},
    {'name': 'Spoon', 'category': 'CUTLERY', 'isReturnable': '1'},
    {'name': 'Knife', 'category': 'CUTLERY', 'isReturnable': '1'},
    {'name': 'Butter Knife', 'category': 'CUTLERY', 'isReturnable': '1'},
    // Cooking
    {'name': 'Kadai (Large)', 'category': 'COOKING', 'isReturnable': '1'},
    {'name': 'Kadai (Medium)', 'category': 'COOKING', 'isReturnable': '1'},
    {'name': 'Pressure Cooker', 'category': 'COOKING', 'isReturnable': '1'},
    {'name': 'Gas Cylinder', 'category': 'COOKING', 'isReturnable': '1'},
    {'name': 'Burner Stand', 'category': 'COOKING', 'isReturnable': '1'},
    // Consumables (Non-returnable)
    {'name': 'Paper Plate', 'category': 'CONSUMABLE', 'isReturnable': '0'},
    {'name': 'Paper Glass', 'category': 'CONSUMABLE', 'isReturnable': '0'},
    {'name': 'Tissue Roll', 'category': 'CONSUMABLE', 'isReturnable': '0'},
    {'name': 'Banana Leaf', 'category': 'CONSUMABLE', 'isReturnable': '0'},
    {'name': 'Aluminium Foil', 'category': 'CONSUMABLE', 'isReturnable': '0'},
    {'name': 'Plastic Wrap', 'category': 'CONSUMABLE', 'isReturnable': '0'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUtensils();
  }

  Future<void> _loadUtensils() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    final result = await db.query('utensils', orderBy: 'category, name');
    
    // Seed default utensils if table is empty (first time)
    if (result.isEmpty && !_seeded) {
      _seeded = true;
      await _seedDefaults();
      return;
    }
    
    setState(() {
      _utensils = result;
      _isLoading = false;
    });
  }

  Future<void> _seedDefaults() async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();
    for (final u in _defaultUtensils) {
      try {
        await db.insert('utensils', {
          'firmId': 'DEFAULT',
          'name': u['name'],
          'category': u['category'],
          'isReturnable': int.parse(u['isReturnable']!),
          'createdAt': now,
        });
      } catch (_) {} // Ignore duplicates
    }
    _loadUtensils();
  }

  Future<void> _addOrEditUtensil([Map<String, dynamic>? utensil]) async {
    final isEdit = utensil != null;
    final nameController = TextEditingController(text: utensil?['name'] ?? '');
    String category = utensil?['category'] ?? 'SERVING';
    bool isReturnable = (utensil?['isReturnable'] ?? 1) == 1;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Utensil' : 'Add Utensil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Utensil Name *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'SERVING', child: Text('Serving')),
                    DropdownMenuItem(value: 'COOKING', child: Text('Cooking')),
                    DropdownMenuItem(value: 'CUTLERY', child: Text('Cutlery')),
                    DropdownMenuItem(value: 'CONSUMABLE', child: Text('Consumable')),
                  ],
                  onChanged: (v) => setDialogState(() => category = v ?? 'SERVING'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Returnable'),
                  subtitle: Text(isReturnable ? 'Must be returned' : 'Consumable (no return)'),
                  value: isReturnable,
                  onChanged: (v) => setDialogState(() => isReturnable = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final db = await DatabaseHelper().database;
                final now = DateTime.now().toIso8601String();
                final data = {
                  'name': nameController.text.trim(),
                  'category': category,
                  'isReturnable': isReturnable ? 1 : 0,
                  'firmId': 'DEFAULT',
                };
                if (isEdit) {
                  await db.update('utensils', data, where: 'id = ?', whereArgs: [utensil['id']]);
                } else {
                  data['createdAt'] = now;
                  await db.insert('utensils', data);
                }
                Navigator.pop(ctx);
                _loadUtensils();
              },
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUtensil(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Utensil?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper().database;
      await db.delete('utensils', where: 'id = ?', whereArgs: [id]);
      _loadUtensils();
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'SERVING': return Colors.blue;
      case 'COOKING': return Colors.orange;
      case 'CUTLERY': return Colors.purple;
      case 'CONSUMABLE': return Colors.grey;
      default: return Colors.indigo;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'SERVING': return Icons.room_service;
      case 'COOKING': return Icons.outdoor_grill;
      case 'CUTLERY': return Icons.restaurant;
      case 'CONSUMABLE': return Icons.delete_outline;
      default: return Icons.kitchen;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group by category
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final u in _utensils) {
      final cat = u['category'] ?? 'OTHER';
      grouped.putIfAbsent(cat, () => []).add(u);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utensil Master'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _addOrEditUtensil()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _utensils.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.kitchen_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No utensils added'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _addOrEditUtensil(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Utensil'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: grouped.entries.map((entry) {
                    final category = entry.key;
                    final items = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(_categoryIcon(category), color: _categoryColor(category)),
                              const SizedBox(width: 8),
                              Text(
                                category,
                                style: TextStyle(fontWeight: FontWeight.bold, color: _categoryColor(category)),
                              ),
                            ],
                          ),
                        ),
                        ...items.map((u) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(u['name']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (u['isReturnable'] == 0)
                                  Chip(
                                    label: const Text('Consumable', style: TextStyle(fontSize: 10)),
                                    backgroundColor: Colors.grey.shade200,
                                  ),
                                PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'edit') _addOrEditUtensil(u);
                                    if (action == 'delete') _deleteUtensil(u['id']);
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditUtensil(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
