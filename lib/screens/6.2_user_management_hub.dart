// MODULE: ACCESS CONTROL & USER MANAGEMENT HUB
// Tabs: Users, Suppliers, Subcontractors
// Features: RBAC, showRates toggle, module access
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../core/app_theme.dart';
import '../services/permission_service.dart';

class UserManagementHubScreen extends StatefulWidget {
  const UserManagementHubScreen({super.key});

  @override
  State<UserManagementHubScreen> createState() => _UserManagementHubScreenState();
}

class _UserManagementHubScreenState extends State<UserManagementHubScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentFirmId;
  bool _isLoading = true;
  
  // Data lists
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _subcontractors = [];
  
  // Roles with expanded options
  final List<String> _roles = [
    'Admin', 'Manager', 'Staff', 'Accountant', 'Driver', 'Vendor', 'Subcontractor'
  ];

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
    _currentFirmId = sp.getString('last_firm');
    
    if (_currentFirmId != null) {
      final db = await DatabaseHelper().database;
      
      final users = await db.query('users', 
        where: 'firmId = ?', 
        whereArgs: [_currentFirmId],
        orderBy: 'role, username',
      );
      
      final suppliers = await db.query('suppliers',
        where: 'firmId = ?',
        whereArgs: [_currentFirmId],
        orderBy: 'name',
      );
      
      final subcontractors = await db.query('subcontractors',
        where: 'firmId = ?',
        whereArgs: [_currentFirmId],
        orderBy: 'name',
      );
      
      setState(() {
        _users = users;
        _suppliers = suppliers;
        _subcontractors = subcontractors;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Access Control"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: const Icon(Icons.people), text: 'Users (${_users.length})'),
            Tab(icon: const Icon(Icons.store), text: 'Suppliers (${_suppliers.length})'),
            Tab(icon: const Icon(Icons.handshake), text: 'Subcontract (${_subcontractors.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleAdd,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(),
                _buildSuppliersTab(),
                _buildSubcontractorsTab(),
              ],
            ),
    );
  }

  void _handleAdd() {
    switch (_tabController.index) {
      case 0: _addUser(); break;
      case 1: _addSupplier(); break;
      case 2: _addSubcontractor(); break;
    }
  }

  // ========== USERS TAB ==========
  Widget _buildUsersTab() {
    if (_users.isEmpty) {
      return _buildEmptyState('No users found', Icons.people_outline, 'Add User', _addUser);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final role = user['role'] ?? 'User';
        final showRates = (user['showRates'] ?? 1) == 1;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(role).withOpacity(0.2),
              child: Icon(Icons.person, color: _getRoleColor(role)),
            ),
            title: Text(user['username'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(role, style: TextStyle(fontSize: 11, color: _getRoleColor(role))),
                ),
                const SizedBox(width: 8),
                Text(user['mobile'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show Rates Toggle
                    SwitchListTile(
                      title: const Text('Can View Rates/Costs'),
                      subtitle: Text(showRates ? 'User can see prices' : 'Prices are hidden'),
                      value: showRates,
                      onChanged: (val) => _toggleShowRates(user, val),
                      activeColor: Colors.green,
                    ),
                    const Divider(),
                    // Module Access - EDITABLE by Admin
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Module Access:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: () => _editModuleAccess(user),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _getUserModules(user).map((m) => Chip(
                        label: Text(m, style: const TextStyle(fontSize: 11)),
                        backgroundColor: Colors.blue.shade50,
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _removeModuleFromUser(user, m),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _editUserRole(user),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Change Role'),
                        ),
                        TextButton.icon(
                          onPressed: () => _confirmDeleteUser(user),
                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                          label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _getModulesForRole(String role) {
    final perms = PermissionService.getDefaultPermissions(role);
    if (perms == 'ALL') return PermissionService.allModules;
    return perms.split(',');
  }
  
  /// Get user's actual module access (custom or role-based)
  List<String> _getUserModules(Map<String, dynamic> user) {
    final customAccess = user['moduleAccess']?.toString();
    if (customAccess != null && customAccess.isNotEmpty && customAccess != 'null') {
      if (customAccess == 'ALL') return PermissionService.allModules;
      return customAccess.split(',').where((m) => m.isNotEmpty).toList();
    }
    // Fall back to role defaults
    return _getModulesForRole(user['role'] ?? 'Staff');
  }
  
  /// Remove a single module from user access
  Future<void> _removeModuleFromUser(Map<String, dynamic> user, String module) async {
    final currentModules = _getUserModules(user);
    currentModules.remove(module);
    
    final db = await DatabaseHelper().database;
    await db.update('users', {
      'moduleAccess': currentModules.join(','),
    }, where: 'id = ?', whereArgs: [user['id']]);
    
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $module access'), backgroundColor: Colors.orange),
      );
    }
  }
  
  /// Edit module access with checkboxes
  Future<void> _editModuleAccess(Map<String, dynamic> user) async {
    final allModules = PermissionService.allModules;
    final currentModules = Set<String>.from(_getUserModules(user));
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Module Access: ${user['username']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setDialogState(() => currentModules.addAll(allModules)),
                      child: const Text('Select All'),
                    ),
                    TextButton(
                      onPressed: () => setDialogState(() => currentModules.clear()),
                      child: const Text('Clear All'),
                    ),
                    TextButton(
                      onPressed: () => setDialogState(() {
                        currentModules.clear();
                        currentModules.addAll(_getModulesForRole(user['role'] ?? 'Staff'));
                      }),
                      child: const Text('Reset to Role'),
                    ),
                  ],
                ),
                const Divider(),
                // Module checkboxes
                ...allModules.map((module) => CheckboxListTile(
                  title: Text(module),
                  subtitle: Text(_getModuleDescription(module), style: const TextStyle(fontSize: 11)),
                  value: currentModules.contains(module),
                  onChanged: (val) => setDialogState(() {
                    if (val == true) {
                      currentModules.add(module);
                    } else {
                      currentModules.remove(module);
                    }
                  }),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final db = await DatabaseHelper().database;
                await db.update('users', {
                  'moduleAccess': currentModules.isEmpty ? '' : currentModules.join(','),
                }, where: 'id = ?', whereArgs: [user['id']]);
                Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Module access updated'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getModuleDescription(String module) {
    switch (module) {
      case 'ORDERS': return 'View and create orders';
      case 'KITCHEN': return 'Kitchen operations & dispatch';
      case 'INVENTORY': return 'Stock & ingredient management';
      case 'FINANCE': return 'Payments & ledger';
      case 'REPORTS': return 'Analytics & reports';
      case 'SETTINGS': return 'System settings';
      case 'DISPATCH': return 'Delivery management';
      case 'STAFF': return 'Staff & attendance';
      default: return '';
    }
  }

  Future<void> _toggleShowRates(Map<String, dynamic> user, bool value) async {
    final db = await DatabaseHelper().database;
    await db.update('users', {'showRates': value ? 1 : 0}, 
      where: 'id = ?', whereArgs: [user['id']]);
    _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Rate visibility enabled' : 'Rates hidden for this user'),
          backgroundColor: value ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _editUserRole(Map<String, dynamic> user) async {
    String selectedRole = user['role'] ?? 'Staff';
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Role: ${user['username']}'),
        content: DropdownButtonFormField<String>(
          value: selectedRole,
          items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => selectedRole = v!,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final db = await DatabaseHelper().database;
              await db.update('users', {
                'role': selectedRole,
                'permissions': PermissionService.getDefaultPermissions(selectedRole),
              }, where: 'id = ?', whereArgs: [user['id']]);
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // ========== SUPPLIERS TAB ==========
  Widget _buildSuppliersTab() {
    if (_suppliers.isEmpty) {
      return _buildEmptyState('No suppliers found', Icons.store_outlined, 'Add Supplier', _addSupplier);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _suppliers.length,
      itemBuilder: (context, index) {
        final supplier = _suppliers[index];
        final isActive = (supplier['isActive'] ?? 1) == 1;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isActive ? null : Colors.grey.shade100,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              child: const Icon(Icons.store, color: Colors.purple),
            ),
            title: Text(supplier['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (supplier['contactPerson'] != null)
                  Text('Contact: ${supplier['contactPerson']}'),
                Row(
                  children: [
                    if (supplier['mobile'] != null) ...[
                      const Icon(Icons.phone, size: 14),
                      const SizedBox(width: 4),
                      Text(supplier['mobile'], style: const TextStyle(fontSize: 12)),
                    ],
                    if (supplier['category'] != null) ...[
                      const SizedBox(width: 12),
                      Chip(label: Text(supplier['category'], style: const TextStyle(fontSize: 10))),
                    ],
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(isActive ? 'Deactivate' : 'Activate'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (v) => _handleSupplierAction(v, supplier),
            ),
          ),
        );
      },
    );
  }

  void _handleSupplierAction(String action, Map<String, dynamic> supplier) async {
    final db = await DatabaseHelper().database;
    switch (action) {
      case 'edit':
        _addSupplier(supplier);
        break;
      case 'toggle':
        final newVal = (supplier['isActive'] ?? 1) == 1 ? 0 : 1;
        await db.update('suppliers', {'isActive': newVal}, where: 'id = ?', whereArgs: [supplier['id']]);
        _loadData();
        break;
      case 'delete':
        await db.delete('suppliers', where: 'id = ?', whereArgs: [supplier['id']]);
        _loadData();
        break;
    }
  }

  // ========== SUBCONTRACTORS TAB ==========
  Widget _buildSubcontractorsTab() {
    if (_subcontractors.isEmpty) {
      return _buildEmptyState('No subcontractors found', Icons.handshake_outlined, 'Add Subcontractor', _addSubcontractor);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _subcontractors.length,
      itemBuilder: (context, index) {
        final sub = _subcontractors[index];
        final isActive = (sub['isActive'] ?? 1) == 1;
        final rating = sub['rating'] ?? 3;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isActive ? null : Colors.grey.shade100,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: const Icon(Icons.handshake, color: Colors.teal),
            ),
            title: Row(
              children: [
                Text(sub['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ...List.generate(5, (i) => Icon(
                  Icons.star,
                  size: 14,
                  color: i < rating ? Colors.amber : Colors.grey.shade300,
                )),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sub['specialization'] != null)
                  Text('Speciality: ${sub['specialization']}'),
                Row(
                  children: [
                    if (sub['mobile'] != null) ...[
                      const Icon(Icons.phone, size: 14),
                      const SizedBox(width: 4),
                      Text(sub['mobile'], style: const TextStyle(fontSize: 12)),
                    ],
                    if (sub['ratePerPax'] != null && (sub['ratePerPax'] as num) > 0) ...[
                      const SizedBox(width: 12),
                      Text('₹${sub['ratePerPax']}/pax', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'rate', child: Text('Update Rating')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (v) => _handleSubcontractorAction(v, sub),
            ),
          ),
        );
      },
    );
  }

  void _handleSubcontractorAction(String action, Map<String, dynamic> sub) async {
    final db = await DatabaseHelper().database;
    switch (action) {
      case 'edit':
        _addSubcontractor(sub);
        break;
      case 'rate':
        _updateRating(sub);
        break;
      case 'delete':
        await db.delete('subcontractors', where: 'id = ?', whereArgs: [sub['id']]);
        _loadData();
        break;
    }
  }

  Future<void> _updateRating(Map<String, dynamic> sub) async {
    int rating = sub['rating'] ?? 3;
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Rate ${sub['name']}'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              icon: Icon(Icons.star, color: i < rating ? Colors.amber : Colors.grey),
              onPressed: () => setDialogState(() => rating = i + 1),
            )),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final db = await DatabaseHelper().database;
                await db.update('subcontractors', {'rating': rating}, where: 'id = ?', whereArgs: [sub['id']]);
                Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ========== ADD DIALOGS ==========
  Future<void> _addUser() async {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'Staff';
    bool showRates = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, maxLength: 10, decoration: const InputDecoration(labelText: 'Mobile', border: OutlineInputBorder(), counterText: '')),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Can View Rates'),
                  value: showRates,
                  onChanged: (v) => setDialogState(() => showRates = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                // Validate each field with specific errors
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required'), backgroundColor: Colors.orange));
                  return;
                }
                if (mobileCtrl.text.trim().length != 10) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mobile must be exactly 10 digits'), backgroundColor: Colors.orange));
                  return;
                }
                if (passCtrl.text.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 4 characters'), backgroundColor: Colors.orange));
                  return;
                }
                final db = DatabaseHelper();
                await db.insertUser({
                  'firmId': _currentFirmId!,
                  'userId': 'U-${mobileCtrl.text}',
                  'username': nameCtrl.text.trim(),
                  'passwordHash': passCtrl.text.trim(),
                  'role': selectedRole,
                  'mobile': mobileCtrl.text.trim(),
                  'isActive': 1,
                  'showRates': showRates ? 1 : 0,
                  'permissions': PermissionService.getDefaultPermissions(selectedRole),
                  'createdAt': DateTime.now().toIso8601String(),
                });
                Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSupplier([Map<String, dynamic>? existing]) async {
    final nameCtrl = TextEditingController(text: existing?['name']);
    final contactCtrl = TextEditingController(text: existing?['contactPerson']);
    final mobileCtrl = TextEditingController(text: existing?['mobile']);
    final emailCtrl = TextEditingController(text: existing?['email']);
    final addressCtrl = TextEditingController(text: existing?['address']);
    final gstCtrl = TextEditingController(text: existing?['gstNumber']);
    String category = existing?['category'] ?? 'GENERAL';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Supplier' : 'Edit Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Company Name *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact Person', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: ['GENERAL', 'VEGETABLES', 'MEAT', 'DAIRY', 'GROCERIES', 'UTENSILS', 'PACKAGING']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => category = v!,
              ),
              const SizedBox(height: 12),
              TextField(controller: gstCtrl, decoration: const InputDecoration(labelText: 'GST Number', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final db = await DatabaseHelper().database;
              final data = {
                'firmId': _currentFirmId!,
                'name': nameCtrl.text.trim(),
                'contactPerson': contactCtrl.text.trim(),
                'mobile': mobileCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
                'gstNumber': gstCtrl.text.trim(),
                'category': category,
                'isActive': 1,
                'updatedAt': DateTime.now().toIso8601String(),
              };
              if (existing == null) {
                data['createdAt'] = DateTime.now().toIso8601String();
                await db.insert('suppliers', data);
              } else {
                await db.update('suppliers', data, where: 'id = ?', whereArgs: [existing['id']]);
              }
              Navigator.pop(ctx);
              _loadData();
            },
            child: Text(existing == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSubcontractor([Map<String, dynamic>? existing]) async {
    final nameCtrl = TextEditingController(text: existing?['name']);
    final contactCtrl = TextEditingController(text: existing?['contactPerson']);
    final mobileCtrl = TextEditingController(text: existing?['mobile']);
    final emailCtrl = TextEditingController(text: existing?['email']);
    final specCtrl = TextEditingController(text: existing?['specialization']);
    final rateCtrl = TextEditingController(text: existing?['ratePerPax']?.toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Subcontractor' : 'Edit Subcontractor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact Person', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Specialization (e.g., Biryani, Sweets)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate per Pax (₹)', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final db = await DatabaseHelper().database;
              final data = {
                'firmId': _currentFirmId!,
                'name': nameCtrl.text.trim(),
                'contactPerson': contactCtrl.text.trim(),
                'mobile': mobileCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'specialization': specCtrl.text.trim(),
                'ratePerPax': double.tryParse(rateCtrl.text) ?? 0,
                'isActive': 1,
                'rating': existing?['rating'] ?? 3,
                'updatedAt': DateTime.now().toIso8601String(),
              };
              if (existing == null) {
                data['createdAt'] = DateTime.now().toIso8601String();
                await db.insert('subcontractors', data);
              } else {
                await db.update('subcontractors', data, where: 'id = ?', whereArgs: [existing['id']]);
              }
              Navigator.pop(ctx);
              _loadData();
            },
            child: Text(existing == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Remove ${user['username']}?'),
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
      await DatabaseHelper().deleteUser(user['id']);
      _loadData();
    }
  }

  // ========== HELPERS ==========
  Widget _buildEmptyState(String message, IconData icon, String buttonText, VoidCallback onTap) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add),
            label: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Admin': return Colors.red;
      case 'Manager': return Colors.blue;
      case 'Accountant': return Colors.green;
      case 'Staff': return Colors.orange;
      case 'Driver': return Colors.purple;
      case 'Vendor': return Colors.teal;
      case 'Subcontractor': return Colors.brown;
      default: return Colors.grey;
    }
  }
}
