import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../core/app_theme.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _firmId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final sp = await SharedPreferences.getInstance();
    _firmId = sp.getString('last_firm');
    final userId = sp.getString('user_id');

    // If no userId, try to find by mobile
    final mobile = sp.getString('last_mobile');

    if (_firmId != null) {
      final db = DatabaseHelper();
      final users = await db.getUsersByFirm(_firmId!);
      
      Map<String, dynamic>? foundUser;
      
      if (userId != null) {
        foundUser = users.firstWhere((u) => u['userId'] == userId || u['id'].toString() == userId, orElse: () => {});
      }
      
      // Fallback to mobile check
      if ((foundUser == null || foundUser.isEmpty) && mobile != null) {
        foundUser = users.firstWhere((u) => u['mobile'] == mobile, orElse: () => {});
      }

      if (foundUser != null && foundUser.isNotEmpty) {
        _userData = Map.from(foundUser); // Clone to allow editing
        _nameController.text = _userData!['username'] ?? '';
        _mobileController.text = _userData!['mobile'] ?? '';
        _passwordController.text = _userData!['passwordHash'] ?? '';
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_userData == null) return;
    if (_nameController.text.isEmpty || _passwordController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill valid name and password (min 4 chars)')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // Update data
    _userData!['username'] = _nameController.text.trim();
    _userData!['mobile'] = _mobileController.text.trim(); // Allow mobile change? Maybe risky if it's the key.
    _userData!['passwordHash'] = _passwordController.text.trim();
    _userData!['updatedAt'] = DateTime.now().toIso8601String();

    try {
      await DatabaseHelper().updateUser(_userData!);
      
      // Update SharedPrefs if mobile changed
      final sp = await SharedPreferences.getInstance();
      await sp.setString('last_mobile', _userData!['mobile']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile Updated Successfully')),
        );
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Profile"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text("User profile not found."))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.indigo,
                        child: Icon(Icons.person, size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      Text("Role: ${_userData!['role'] ?? 'User'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 20),
                      
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _mobileController,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone_android),
                          border: OutlineInputBorder(),
                          helperText: 'Changing mobile will affect your login ID',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 30),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Save Changes", style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
