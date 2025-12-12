// MODULE: OPERATIONS HUB (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-08 | Features: Role-Based Access, Kitchen, Dispatch, My Attendance, Staff (Admin), Utensils
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '3.1_kitchen_screen.dart';
import '5.0_dispatch_hub_screen.dart';
import '3.3_staff_screen.dart';
import '3.3.3_my_attendance_screen.dart';
import '3.4_utensils_screen.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final sp = await SharedPreferences.getInstance();
    String role = sp.getString('last_role') ?? '';
    
    // If role not in SharedPreferences, try to get from database
    if (role.isEmpty) {
      final mobile = sp.getString('last_mobile');
      final firmId = sp.getString('last_firm');
      
      if (mobile != null && firmId != null) {
        final db = await DatabaseHelper().database;
        final users = await db.query('users', 
          where: 'mobile = ? AND firmId = ?', 
          whereArgs: [mobile, firmId],
        );
        if (users.isNotEmpty) {
          role = users.first['role']?.toString() ?? '';
          // Save to SharedPreferences for next time
          await sp.setString('last_role', role);
        }
      }
    }
    
    debugPrint('🔑 Operations - User role: "$role"');
    
    setState(() {
      // Admin, Owner, and Manager can access Staff Management
      _isAdmin = role.toLowerCase() == 'admin' || 
                 role.toLowerCase() == 'owner' ||
                 role.toLowerCase() == 'manager';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Row 1: Kitchen & Dispatch
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildOperationCard(
                      context,
                      title: AppLocalizations.of(context)!.kitchenView,
                      icon: Icons.kitchen,
                      color: Colors.orange,
                      onTap: () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const KitchenScreen(), fullscreenDialog: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildOperationCard(
                      context,
                      title: AppLocalizations.of(context)!.dispatchView,
                      icon: Icons.delivery_dining,
                      color: Colors.green,
                      onTap: () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const DispatchScreen(), fullscreenDialog: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Row 2: My Attendance (always visible), Staff Management (admin only), Utensils
            Expanded(
              child: Row(
                children: [
                  // My Attendance - Always visible
                  Expanded(
                    child: _buildOperationCard(
                      context,
                      title: AppLocalizations.of(context)!.attendanceTitle,
                      subtitle: AppLocalizations.of(context)!.punchInOut,
                      icon: Icons.fingerprint,
                      color: Colors.teal,
                      onTap: () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const MyAttendanceScreen(), fullscreenDialog: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Staff Management - Admin Only
                  Expanded(
                    child: _isAdmin
                        ? _buildOperationCard(
                            context,
                            title: AppLocalizations.of(context)!.staffManagement,
                            subtitle: AppLocalizations.of(context)!.adminOnly,
                            icon: Icons.people,
                            color: Colors.blue,
                            onTap: () => Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(builder: (_) => const StaffScreen(), fullscreenDialog: true),
                            ),
                          )
                        : _buildLockedCard(
                            context,
                            title: AppLocalizations.of(context)!.staffManagement,
                            subtitle: AppLocalizations.of(context)!.adminOnly,
                            icon: Icons.people,
                          ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Utensils
                  Expanded(
                    child: _buildOperationCard(
                      context,
                      title: AppLocalizations.of(context)!.utensils,
                      icon: Icons.inventory_2,
                      color: Colors.purple,
                      onTap: () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const UtensilsScreen(), fullscreenDialog: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationCard(BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedCard(BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      color: Colors.grey.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.restrictedToAdmins),
              backgroundColor: Colors.red,
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.shade300,
                  child: Icon(icon, size: 28, color: Colors.grey.shade500),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock, size: 12, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }
}
