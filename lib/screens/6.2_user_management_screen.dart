import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../core/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _currentFirmId;
  
  // RBAC Roles
  final List<String> _roles = ['Admin', 'Manager', 'Staff', 'Accountant'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final sp = await SharedPreferences.getInstance();
    _currentFirmId = sp.getString('last_firm');
    
    if (_currentFirmId != null) {
      final users = await DatabaseHelper().getUsersByFirm(_currentFirmId!);
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addUser() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final mobileController = TextEditingController();
    String selectedRole = 'Staff';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Add New User"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: "Full Name",
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: "Mobile Number",
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        counterText: "",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: "Role",
                        prefixIcon: Icon(Icons.security),
                        border: OutlineInputBorder(),
                      ),
                      items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) => setState(() => selectedRole = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    if (usernameController.text.isEmpty || 
                        mobileController.text.length != 10 || 
                        passwordController.text.length < 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please fill all fields correctly")),
                      );
                      return;
                    }
                    
                    final db = DatabaseHelper();
                    final mobile = mobileController.text.trim();
                    
                    // 1. Check/Add Authorization
                    bool isAuthorized = await db.isMobileAuthorized(_currentFirmId!, mobile);
                    if (!isAuthorized) {
                      // Auto-authorize if adding from User Management
                      await db.addAuthorizedMobile(
                        firmId: _currentFirmId!,
                        mobile: mobile,
                        type: 'USER',
                        name: usernameController.text.trim(),
                        addedBy: 'ADMIN_UI',
                      );
                    }

                    // 2. Create User
                    try {
                      await db.insertUser({
                        'firmId': _currentFirmId!,
                        'userId': 'U-$mobile',
                        'username': usernameController.text.trim(),
                        'passwordHash': passwordController.text.trim(),
                        'role': selectedRole,
                        'mobile': mobile,
                        'isActive': 1,
                        'createdAt': DateTime.now().toIso8601String(),
                        'permissions': _getPermissionsForRole(selectedRole),
                      });
                      
                      if (context.mounted) Navigator.pop(context);
                      _loadData();
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("User added successfully"), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text("Create User"),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  String _getPermissionsForRole(String role) {
    switch (role) {
      case 'Admin': return 'ALL';
      case 'Manager': return 'ORDERS,INVENTORY,OPERATIONS,REPORTS';
      case 'Accountant': return 'FINANCE,REPORTS';
      case 'Staff': return 'ORDERS,OPERATIONS';
      default: return 'NONE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Management"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text("No users found"))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final role = user['role'] ?? 'User';
                    
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(role).withOpacity(0.2),
                          child: Icon(Icons.person, color: _getRoleColor(role)),
                        ),
                        title: Text(user['username'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(role).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _getRoleColor(role).withOpacity(0.5)),
                                  ),
                                  child: Text(role, style: TextStyle(fontSize: 12, color: _getRoleColor(role), fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.phone_android, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(user['mobile'] ?? 'N/A', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmDelete(user),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
  
  Color _getRoleColor(String role) {
    switch (role) {
      case 'Admin': return Colors.red;
      case 'Manager': return Colors.blue;
      case 'Accountant': return Colors.green;
      case 'Staff': return Colors.orange;
      default: return Colors.grey;
    }
  }
  
  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Are you sure you want to delete ${user['username']}?"),
            const SizedBox(height: 12),
            const Text("This will remove their login access immediately.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await DatabaseHelper().deleteUser(user['id']);
      
      // Optional: Also de-authorize mobile?
      // For now, we just delete the user account. 
      // The mobile remains authorized but no user account exists.
      
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User deleted"), backgroundColor: Colors.orange),
        );
      }
    }
  }
}
