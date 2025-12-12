// MODULE: SUPPLIER MASTER
// Last Updated: 2025-12-09 | Features: CRUD for suppliers
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  String? _firmId;

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
      _suppliers = await DatabaseHelper().getAllSuppliers(_firmId!);
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _addOrEditSupplier([Map<String, dynamic>? existing]) async {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final mobileController = TextEditingController(text: existing?['mobile'] ?? '');
    final emailController = TextEditingController(text: existing?['email'] ?? '');
    final addressController = TextEditingController(text: existing?['address'] ?? '');
    final gstController = TextEditingController(text: existing?['gstNumber'] ?? '');
    final bankAccountController = TextEditingController(text: existing?['bankAccountNo'] ?? '');
    final bankIfscController = TextEditingController(text: existing?['bankIfsc'] ?? '');
    final bankNameController = TextEditingController(text: existing?['bankName'] ?? '');
    String category = existing?['category'] ?? 'Vegetable';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? AppLocalizations.of(context)!.editSupplier : AppLocalizations.of(context)!.addSupplier),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.nameRequired, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobileController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.mobile, border: const OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.email, border: const OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.category, border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'Vegetable', child: Text(AppLocalizations.of(context)!.catVegetable)),
                    DropdownMenuItem(value: 'Meat', child: Text(AppLocalizations.of(context)!.catMeat)),
                    DropdownMenuItem(value: 'Seafood', child: Text(AppLocalizations.of(context)!.catSeafood)),
                    DropdownMenuItem(value: 'Grocery', child: Text(AppLocalizations.of(context)!.catGrocery)),
                    DropdownMenuItem(value: 'Dairy', child: Text(AppLocalizations.of(context)!.catDairy)),
                    DropdownMenuItem(value: 'Other', child: Text(AppLocalizations.of(context)!.catOther)),
                  ],
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.address, border: const OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gstController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.gstNumber, border: const OutlineInputBorder()),
                ),
                const Divider(height: 24),
                Text(AppLocalizations.of(context)!.bankDetails, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: bankNameController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.bankName, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankAccountController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.accountNumber, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankIfscController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.ifscCode, border: const OutlineInputBorder()),
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
                    SnackBar(content: Text(AppLocalizations.of(context)!.enterSupplierName), backgroundColor: Colors.red),
                  );
                  return;
                }
                
                final data = {
                  'firmId': _firmId,
                  'name': nameController.text.trim(),
                  'mobile': mobileController.text.trim(),
                  'email': emailController.text.trim(),
                  'address': addressController.text.trim(),
                  'category': category,
                  'gstNumber': gstController.text.trim(),
                  'bankAccountNo': bankAccountController.text.trim(),
                  'bankIfsc': bankIfscController.text.trim(),
                  'bankName': bankNameController.text.trim(),
                };
                
                if (isEdit) {
                  await DatabaseHelper().updateSupplier(existing['id'], data);
                } else {
                  await DatabaseHelper().insertSupplier(data);
                }
                Navigator.pop(context, true);
              },
              child: Text(isEdit ? AppLocalizations.of(context)!.save : AppLocalizations.of(context)!.add),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? AppLocalizations.of(context)!.supplierUpdated : AppLocalizations.of(context)!.supplierAdded), backgroundColor: Colors.green),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.supplierMaster),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditSupplier(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.noSuppliersAdded),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _addOrEditSupplier(),
                        icon: const Icon(Icons.add),
                        label: Text(AppLocalizations.of(context)!.addSupplier),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = _suppliers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getCategoryColor(supplier['category'] ?? 'Other'),
                          child: const Icon(Icons.local_shipping, color: Colors.white),
                        ),
                        title: Text(supplier['name'] ?? AppLocalizations.of(context)!.unknown,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supplier['mobile'] ?? AppLocalizations.of(context)!.noPhone),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(supplier['category'] ?? 'Other').withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(supplier['category'] ?? 'Other', 
                                style: TextStyle(fontSize: 11, color: _getCategoryColor(supplier['category'] ?? 'Other'))),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _addOrEditSupplier(supplier),
                        ),
                        onTap: () => _addOrEditSupplier(supplier),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Vegetable': return Colors.green;
      case 'Meat': return Colors.red;
      case 'Seafood': return Colors.blue;
      case 'Grocery': return Colors.brown;
      case 'Dairy': return Colors.amber;
      default: return Colors.grey;
    }
  }
}
