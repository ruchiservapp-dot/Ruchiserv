// MODULE: SUBCONTRACTOR MASTER
// Last Updated: 2025-12-09 | Features: CRUD for subcontractors
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class SubcontractorScreen extends StatefulWidget {
  const SubcontractorScreen({super.key});

  @override
  State<SubcontractorScreen> createState() => _SubcontractorScreenState();
}

class _SubcontractorScreenState extends State<SubcontractorScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _subcontractors = [];
  bool _isLoading = true;
  String? _firmId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      _subcontractors = await DatabaseHelper().getAllSubcontractors(_firmId!);
    }
    
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _filterByTab() {
    if (_subcontractors.isEmpty) return [];
    
    switch (_tabController.index) {
      case 0: // All
        return _subcontractors;
      case 1: // Food
        return _subcontractors.where((s) => (s['category'] ?? 'FOOD') == 'FOOD').toList();
      case 2: // Event
        return _subcontractors.where((s) => (s['category'] ?? '') == 'EVENT').toList();
      default:
        return _subcontractors;
    }
  }

  Future<void> _addOrEdit([Map<String, dynamic>? existing]) async {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final mobileController = TextEditingController(text: existing?['mobile'] ?? '');
    final emailController = TextEditingController(text: existing?['email'] ?? '');
    final addressController = TextEditingController(text: existing?['address'] ?? '');
    final specializationController = TextEditingController(text: existing?['specialization'] ?? '');
    final rateController = TextEditingController(text: existing?['ratePerPax']?.toString() ?? '');
    String category = existing?['category'] ?? 'FOOD';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? AppLocalizations.of(context)!.editSubcontractor : AppLocalizations.of(context)!.addSubcontractor),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.kitchenBusinessName, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(labelText: 'Category', border: const OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'FOOD', child: Text('Food Partner')),
                  DropdownMenuItem(value: 'EVENT', child: Text('Event Partner')),
                ],
                onChanged: (v) => category = v!,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.mobileRequired, border: const OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.email, border: const OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.address, border: const OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: specializationController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.specialization,
                  hintText: AppLocalizations.of(context)!.specializationHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.ratePerPax,
                  border: const OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || mobileController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.enterNameMobile), backgroundColor: Colors.red),
                );
                return;
              }
              
              final data = {
                'firmId': _firmId,
                'name': nameController.text.trim(),
                'mobile': mobileController.text.trim(),
                'email': emailController.text.trim(),
                'address': addressController.text.trim(),
                'specialization': specializationController.text.trim(),
                'ratePerPax': double.tryParse(rateController.text) ?? 0,
                'category': category,
              };
              
              if (isEdit) {
                await DatabaseHelper().updateSubcontractor(existing['id'], data);
              } else {
                await DatabaseHelper().insertSubcontractor(data);
              }

              // AUTO-WHITELIST
              if (mobileController.text.trim().isNotEmpty) {
                await DatabaseHelper().insertAuthorizedMobile({
                  'firmId': _firmId,
                  'mobile': mobileController.text.trim(),
                  'role': 'Subcontractor',
                  'name': nameController.text.trim(),
                  'addedBy': 'ADMIN_APP',
                });
              }
              Navigator.pop(context, true);
            },
            child: Text(isEdit ? AppLocalizations.of(context)!.save : AppLocalizations.of(context)!.add),
          ),
        ],
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? AppLocalizations.of(context)!.subcontractorUpdated : AppLocalizations.of(context)!.subcontractorAdded), backgroundColor: Colors.green),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.subcontractorMaster),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Food'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Builder(builder: (context) {
              final filtered = _filterByTab();
              if (filtered.isEmpty) {
                 return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.handshake, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.noSubcontractorsAdded),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _addOrEdit(),
                        icon: const Icon(Icons.add),
                        label: Text(AppLocalizations.of(context)!.addSubcontractor),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final sub = filtered[index];
                    final isEvent = (sub['category'] ?? 'FOOD') == 'EVENT';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isEvent ? Colors.purple.shade100 : Colors.indigo.shade100,
                          child: Icon(isEvent ? Icons.event : Icons.restaurant, color: isEvent ? Colors.purple : Colors.indigo),
                        ),
                        title: Text(sub['name'] ?? AppLocalizations.of(context)!.unknown,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sub['mobile'] ?? AppLocalizations.of(context)!.noPhone),
                            if ((sub['specialization'] ?? '').isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(sub['specialization'], 
                                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${sub['ratePerPax']?.toStringAsFixed(0) ?? '0'}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(AppLocalizations.of(context)!.perPax, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        onTap: () => _addOrEdit(sub),
                      ),
                    );
                  },
                );
            }),
    );
  }
}
