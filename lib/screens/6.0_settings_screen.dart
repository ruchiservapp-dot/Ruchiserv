import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '1.4_login_screen.dart';
import '7.1_audit_report_screen.dart'; // COMPLIANCE: Audit Report (Task B)
import '6.4_general_settings_screen.dart';
import '6.2_user_management_hub.dart'; // Access Control Hub (Users, Suppliers, Subcontractors)
import '6.3_payment_settings_screen.dart';
import '6.5_manage_authorized_mobiles_screen.dart';
import '6.6_subscription_screen.dart';
import '../db/database_helper.dart';
import '6.7_firm_profile_screen.dart';
import '6.8_user_profile_screen.dart'; // User Profile logic
import '6.9_vehicle_master_screen.dart'; // Vehicle Master
import 'dart:io'; // For sharing/local file logic
import 'package:share_plus/share_plus.dart'; // Optional for file share
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../core/locale_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _showUniversalData = true;
  String? _firmId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final sp = await SharedPreferences.getInstance();
    _firmId = sp.getString('last_firm');
    final userId = sp.getString('user_id');
    final mobile = sp.getString('last_mobile');

    if (_firmId != null) {
      final db = DatabaseHelper();
      
      // 1. Check User Role
      final users = await db.getUsersByFirm(_firmId!);
      Map<String, dynamic>? foundUser;
      if (userId != null) {
        foundUser = users.firstWhere((u) => u['userId'] == userId || u['id'].toString() == userId, orElse: () => {});
      }
      if ((foundUser == null || foundUser.isEmpty) && mobile != null) {
        foundUser = users.firstWhere((u) => u['mobile'] == mobile, orElse: () => {});
      }

      if (foundUser != null && foundUser.isNotEmpty) {
        final role = foundUser['role']?.toString() ?? 'User';
        _isAdmin = (role == 'Admin' || role == 'Owner');
      }

      // 2. Check Firm Setting (Universal Data)
      _showUniversalData = await db.getFirmUniversalDataVisibility(_firmId!);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleUniversalData(bool value) async {
    if (_firmId == null) return;
    setState(() => _showUniversalData = value); // Optimistic update
    
    await DatabaseHelper().setFirmUniversalDataVisibility(_firmId!, value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Universal Data Visibility: ${value ? 'ON' : 'OFF'}"),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar removed to avoid duplication with MainMenuScreen
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === FIRM SETTINGS (Admin Only) ===
          if (_isAdmin) ...[
             const Padding(
               padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
               child: Text("Admin Controls", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
             ),
             SwitchListTile(
               title: const Text("Show Universal Data"),
               subtitle: const Text("Display pre-loaded recipes/ingredients alongside firm data"),
               value: _showUniversalData,
               onChanged: _toggleUniversalData,
               secondary: const Icon(Icons.public, color: Colors.teal),
             ),
             const Divider(),
          ],

          ListTile(
            leading: const Icon(Icons.business_rounded, color: Colors.indigo),
            title: const Text("Firm Profile"),
            subtitle: const Text("View or update your firm details"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FirmProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_rounded, color: Colors.indigo),
            title: const Text("User Profile"),
            subtitle: const Text("Manage your login and preferences"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.group_add_rounded, color: Colors.indigo),
            title: const Text("Manage Users"),
            subtitle: const Text("Add users and set permissions"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UserManagementHubScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone_android_rounded, color: Colors.indigo),
            title: const Text("Authorized Mobiles"),
            subtitle: const Text("Manage pre-approved mobile numbers"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageAuthorizedMobilesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.card_membership_rounded, color: Colors.indigo),
            title: const Text("Subscription"),
            subtitle: const Text("View plan and upgrade"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.payment_rounded, color: Colors.indigo),
            title: const Text("Payment Settings"),
            subtitle: const Text("Configure payment gateways"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PaymentSettingsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_rounded, color: Colors.indigo),
            title: const Text("General Settings"),
            subtitle: const Text("Theme, Notifications, Security"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GeneralSettingsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.indigo),
            title: const Text("Language"),
            subtitle: Consumer<LocaleProvider>(
              builder: (context, provider, child) {
                String label = 'English';
                switch (provider.locale?.languageCode) {
                  case 'ml': label = 'Malayalam (മലയാളം)'; break;
                  case 'ta': label = 'Tamil (தமிழ்)'; break;
                  case 'kn': label = 'Kannada (ಕನ್ನಡ)'; break;
                  case 'hi': label = 'Hindi (हिंदी)'; break;
                  case 'te': label = 'Telugu (తెలుగు)'; break;
                }
                return Text(label);
              },
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Select Language'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLanguageOption(context, 'English', 'en'),
                      _buildLanguageOption(context, 'Malayalam (മലയാളം)', 'ml'),
                      _buildLanguageOption(context, 'Tamil (தமிழ்)', 'ta'),
                      _buildLanguageOption(context, 'Kannada (ಕನ್ನಡ)', 'kn'),
                      _buildLanguageOption(context, 'Hindi (हिंदी)', 'hi'),
                      _buildLanguageOption(context, 'Telugu (తెలుగు)', 'te'),
                    ],
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping_rounded, color: Colors.indigo),
            title: const Text("Vehicle Master"),
            subtitle: const Text("Manage fleet vehicles"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VehicleMasterScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_upload_rounded, color: Colors.green),
            title: const Text("Backup to AWS"),
            subtitle: const Text("Upload all data to cloud"),
            onTap: () async {
              // Show confirmation
              final confirm = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Data Backup"),
                  content: const Text("Choose backup method:"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'local'),
                      child: const Text("Local Backup (File)"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'cloud'),
                      child: const Text("Cloud Backup (AWS)"),
                    ),
                  ],
                ),
              );

              if (context.mounted && confirm != null) {
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  String message = '';
                  bool success = false;
                  
                  if (confirm == 'cloud') {
                     final result = await DatabaseHelper().backupAllTablesToAWS();
                     success = (result['status'] == 'success');
                     message = result['message'] ?? result['results'] ?? 'Done';
                  } else {
                     // Local
                     final path = await DatabaseHelper().backupToLocalFile();
                     success = true;
                     message = 'Backed up to: $path';
                     // Optional sharing
                     // Share.shareFiles([path]);
                  }
                  
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(success ? "Backup Successful" : "Backup Failed"),
                        content: Text(message),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e")),
                    );
                  }
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded, color: Colors.indigo),
            title: const Text("About RuchiServ"),
            onTap: () {
              debugPrint('Opening About Dialog');
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("About RuchiServ"),
                  content: const Text(
                    "RuchiServ - Catering Service Management\n\n"
                    "Version 1.0.0\n\n"
                    "Complete solution for managing catering operations, inventory, reports, and more.\n\n"
                    "© 2024 RuchiServ. All rights reserved."
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          // COMPLIANCE: Audit Report (Task B)
          ListTile(
            leading: const Icon(Icons.history_edu, color: AppColors.primary),
            title: const Text('Audit Logs'),
            subtitle: const Text('View and export compliance logs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuditReportScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () async {
              final sp = await SharedPreferences.getInstance();
              await sp.clear();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
  Widget _buildLanguageOption(BuildContext context, String label, String code) {
    return ListTile(
      title: Text(label),
      onTap: () {
        context.read<LocaleProvider>().setLocale(Locale(code));
        Navigator.pop(context);
      },
    );
  }
}
