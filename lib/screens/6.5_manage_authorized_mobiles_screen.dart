import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../core/app_theme.dart';

class ManageAuthorizedMobilesScreen extends StatefulWidget {
  const ManageAuthorizedMobilesScreen({super.key});

  @override
  State<ManageAuthorizedMobilesScreen> createState() => _ManageAuthorizedMobilesScreenState();
}

class _ManageAuthorizedMobilesScreenState extends State<ManageAuthorizedMobilesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _mobiles = [];
  String _filterType = 'ALL';
  final List<String> _types = ['ALL', 'USER', 'SUPPLIER', 'SUBCONTRACTOR'];

  @override
  void initState() {
    super.initState();
    _loadMobiles();
  }

  Future<void> _loadMobiles() async {
    setState(() => _isLoading = true);
    try {
      final sp = await SharedPreferences.getInstance();
      final firmId = sp.getString('last_firm') ?? 'default_firm';
      
      final db = DatabaseHelper();
      final mobiles = await db.getAuthorizedMobiles(
        firmId,
        type: _filterType == 'ALL' ? null : _filterType,
      );

      setState(() {
        _mobiles = mobiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading mobiles: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    String selectedType = 'USER';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Authorized Mobile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mobileController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: ['USER', 'SUPPLIER', 'SUBCONTRACTOR']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => selectedType = val ?? 'USER',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || mobileController.text.trim().length != 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid name and mobile')),
                );
                return;
              }
              
              try {
                final sp = await SharedPreferences.getInstance();
                final firmId = sp.getString('last_firm') ?? 'default_firm';
                final userId = sp.getString('user_id') ?? 'ADMIN';
                
                final db = DatabaseHelper();
                await db.addAuthorizedMobile(
                  firmId: firmId,
                  mobile: mobileController.text.trim(),
                  type: selectedType,
                  name: nameController.text.trim(),
                  addedBy: userId,
                );
                
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) _loadMobiles();
  }

  Future<void> _toggleActive(int id, bool currentStatus) async {
    try {
      final db = DatabaseHelper();
      await db.toggleAuthorizedMobile(id, !currentStatus);
      _loadMobiles();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentStatus ? 'Mobile activated' : 'Mobile deactivated'),
            backgroundColor: !currentStatus ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteMobile(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mobile?'),
        content: Text('Are you sure you want to delete $name? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final db = DatabaseHelper();
        await db.deleteAuthorizedMobile(id);
        _loadMobiles();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mobile deleted'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Authorized Mobiles'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              value: _filterType,
              decoration: const InputDecoration(
                labelText: 'Filter by Type',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _filterType = val);
                  _loadMobiles();
                }
              },
            ),
          ),
          
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _mobiles.isEmpty
                    ? const Center(child: Text('No authorized mobiles found'))
                    : ListView.builder(
                        itemCount: _mobiles.length,
                        itemBuilder: (context, index) {
                          final mobile = _mobiles[index];
                          final isActive = (mobile['isActive'] as int) == 1;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isActive 
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                child: Icon(
                                  isActive ? Icons.check_circle : Icons.cancel,
                                  color: isActive ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(mobile['name'] ?? 'Unknown'),
                              subtitle: Text(
                                '${mobile['mobile']} • ${mobile['type']}\n'
                                'Added: ${mobile['addedAt']?.toString().substring(0, 10) ?? 'Unknown'}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: isActive,
                                    onChanged: (_) => _toggleActive(mobile['id'], isActive),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteMobile(mobile['id'], mobile['name']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
