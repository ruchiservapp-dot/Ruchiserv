// MODULE: UTENSILS TRACKING (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-08 | Features: Stock Management, Add/Edit/Delete, Firm-scoped Data
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class UtensilsScreen extends StatefulWidget {
  const UtensilsScreen({super.key});

  @override
  State<UtensilsScreen> createState() => _UtensilsScreenState();
}

class _UtensilsScreenState extends State<UtensilsScreen> {
  List<Map<String, dynamic>> _utensils = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUtensils();
  }

  Future<void> _loadUtensils() async {
    setState(() => _isLoading = true);
    try {
      final utensils = await DatabaseHelper().getAllUtensils();
      if (mounted) {
        setState(() {
          _utensils = utensils;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading utensils: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addUtensil() async {
    final nameController = TextEditingController();
    final stockController = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.addUtensil),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController, 
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.utensilName,
                  hintText: AppLocalizations.of(context)!.utensilNameHint,
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController, 
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.totalStock,
                  hintText: AppLocalizations.of(context)!.enterQuantity,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.enterUtensilName), backgroundColor: Colors.red),
                  );
                  return;
                }
                
                final stock = int.tryParse(stockController.text) ?? 0;
                
                try {
                  // Get firmId from SharedPreferences
                  final sp = await SharedPreferences.getInstance();
                  final firmId = sp.getString('last_firm') ?? 'DEFAULT';
                  
                  await DatabaseHelper().insertUtensil({
                    'firmId': firmId,
                    'name': name,
                    'totalStock': stock,
                    'availableStock': stock,
                    'createdAt': DateTime.now().toIso8601String(),
                  });
                  
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.utensilAdded), backgroundColor: Colors.green),
                    );
                    _loadUtensils();
                  }
                } catch (e) {
                  debugPrint('Error inserting utensil: $e');
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.error(e.toString())), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(AppLocalizations.of(context)!.add),
            ),
          ],
        );
      },
    );
    
    nameController.dispose();
    stockController.dispose();
  }

  Future<void> _editUtensil(Map<String, dynamic> utensil) async {
    final nameController = TextEditingController(text: utensil['name'] ?? '');
    final totalStockController = TextEditingController(text: (utensil['totalStock'] ?? 0).toString());
    final availableController = TextEditingController(text: (utensil['availableStock'] ?? 0).toString());

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.editUtensil(utensil['name'])),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController, 
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.utensilName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: totalStockController, 
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.totalStock,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: availableController, 
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.availableStock,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: dialogContext,
                  builder: (ctx) => AlertDialog(
                    title: Text(AppLocalizations.of(context)!.deleteUtensil),
                    content: Text(AppLocalizations.of(context)!.deleteUtensilConfirm(utensil['name'])),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: Text(AppLocalizations.of(context)!.delete),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _deleteUtensil(utensil['id']);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(AppLocalizations.of(context)!.delete),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.enterUtensilName), backgroundColor: Colors.red),
                  );
                  return;
                }
                
                try {
                  final db = await DatabaseHelper().database;
                  await db.update(
                    'utensils',
                    {
                      'name': name,
                      'totalStock': int.tryParse(totalStockController.text) ?? 0,
                      'availableStock': int.tryParse(availableController.text) ?? 0,
                      'updatedAt': DateTime.now().toIso8601String(),
                    },
                    where: 'id = ?',
                    whereArgs: [utensil['id']],
                  );
                  
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.utensilUpdated), backgroundColor: Colors.green),
                    );
                    _loadUtensils();
                  }
                } catch (e) {
                  debugPrint('Error updating utensil: $e');
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.error(e.toString())), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        );
      },
    );
    
    nameController.dispose();
    totalStockController.dispose();
    availableController.dispose();
  }

  Future<void> _deleteUtensil(int id) async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete('utensils', where: 'id = ?', whereArgs: [id]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.utensilDeleted), backgroundColor: Colors.orange),
        );
        _loadUtensils();
      }
    } catch (e) {
      debugPrint('Error deleting utensil: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.utensilsTracking),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUtensils),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addUtensil,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _utensils.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.noUtensilsAdded),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _addUtensil,
                        icon: const Icon(Icons.add),
                        label: Text(AppLocalizations.of(context)!.addFirstUtensil),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _utensils.length,
                  itemBuilder: (context, index) {
                    final utensil = _utensils[index];
                    final totalStock = (utensil['totalStock'] as num?)?.toInt() ?? 0;
                    final available = (utensil['availableStock'] as num?)?.toInt() ?? 0;
                    final issued = totalStock - available;
                    final utilizationPercent = totalStock > 0 ? (issued / totalStock) * 100 : 0;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: available > 0 ? Colors.green : Colors.red,
                          child: const Icon(Icons.inventory_2, color: Colors.white),
                        ),
                        title: Text(utensil['name'] ?? AppLocalizations.of(context)!.unknown, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.availableCount(available, totalStock),
                              style: TextStyle(color: available > 0 ? Colors.green : Colors.red)),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: totalStock > 0 ? available / totalStock : 0,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation(
                                available > totalStock * 0.3 ? Colors.green : Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocalizations.of(context)!.issuedCount(issued, utilizationPercent.toStringAsFixed(0)),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editUtensil(utensil),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
