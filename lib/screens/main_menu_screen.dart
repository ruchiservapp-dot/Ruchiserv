// Main Menu Screen - HIDDEN MODULES FOR UNAUTHORIZED USERS
// Only shows modules user is allowed to access
import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../services/feature_gate_service.dart';
import '../services/feature_gate_service.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '2.0_orders_calendar_screen.dart';
import '3.0_operations_screen.dart';
import '4.0_inventory_screen.dart';
import '5.1_finance_screen.dart';
import '5.0_reports_screen.dart';
import '6.0_settings_screen.dart';
import '3.3.3_my_attendance_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  
  String _subscriptionTier = 'BASIC';
  String _userRole = 'Staff';
  
  // Only visible menu items (filtered by role)
  List<Map<String, dynamic>> _visibleMenuItems = [];
  List<Widget> _visibleScreens = [];

  // All possible menu items
  final List<Map<String, dynamic>> _allMenuItems = [
    {'icon': Icons.receipt_long, 'label': 'Orders', 'module': 'ORDERS', 'tier': 'BASIC'},
    {'icon': Icons.settings_suggest, 'label': 'Operations', 'module': 'KITCHEN', 'tier': 'BASIC'},
    {'icon': Icons.inventory_2, 'label': 'Inventory', 'module': 'INVENTORY', 'tier': 'BASIC'},
    {'icon': Icons.account_balance_wallet, 'label': 'Finance', 'module': 'FINANCE', 'tier': 'PRO'},
    {'icon': Icons.bar_chart_rounded, 'label': 'Reports', 'module': 'REPORTS', 'tier': 'BASIC'},
    {'icon': Icons.settings, 'label': 'Settings', 'module': 'SETTINGS', 'tier': 'BASIC'},
  ];

  final List<Widget> _allScreens = const [
    OrderCalendarScreen(),
    OperationsScreen(),
    InventoryScreen(),
    FinanceScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final role = await PermissionService.instance.getUserRole();
    final allowedModules = await PermissionService.instance.getAllowedModules();
    final tier = await FeatureGateService.instance.getCurrentTier();
    
    // Filter menu items based on permissions
    List<Map<String, dynamic>> visible = [];
    List<Widget> screens = [];
    
    // Special case: Staff only sees My Attendance
    if (role == 'Staff' || role == 'Driver') {
      visible = [
        {'icon': Icons.fingerprint, 'label': 'My Attendance', 'module': 'ATTENDANCE', 'tier': 'BASIC'},
      ];
      screens = [const MyAttendanceScreen()];
    } else {
      // For other roles, filter based on module access
      for (int i = 0; i < _allMenuItems.length; i++) {
        final item = _allMenuItems[i];
        final module = item['module'] as String;
        
        // Check if user can access this module
        bool hasAccess = role == 'Admin' || 
            allowedModules.contains(module) || 
            allowedModules.contains('ALL');
        
        // Check tier requirements
        final requiredTier = item['tier'] as String;
        bool hasTier = _checkTierAccess(tier, requiredTier);
        
        if (hasAccess && hasTier) {
          visible.add(item);
          screens.add(_allScreens[i]);
        }
      }
      
      // If nothing visible, at least show Orders
      if (visible.isEmpty) {
        visible.add(_allMenuItems[0]);
        screens.add(_allScreens[0]);
      }
    }
    
    setState(() {
      _userRole = role;
      _subscriptionTier = tier;
      _visibleMenuItems = visible;
      _visibleScreens = screens;
      _selectedIndex = 0;
      _isLoading = false;
    });
  }

  bool _checkTierAccess(String currentTier, String requiredTier) {
    if (currentTier == 'ENTERPRISE') return true;
    if (currentTier == 'PRO' && (requiredTier == 'PRO' || requiredTier == 'BASIC')) return true;
    if (currentTier == 'BASIC' && requiredTier == 'BASIC') return true;
    return false;
  }

  void _onMenuTap(int index) {
    if (index >= 0 && index < _visibleMenuItems.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Handle empty state
    if (_visibleMenuItems.isEmpty || _visibleScreens.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.noModulesAvailable),
              Text(AppLocalizations.of(context)!.contactAdministrator, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }
    
    
    final moduleName = _getLocalizedLabel(context, _visibleMenuItems[_selectedIndex]['module']);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          moduleName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Only show tier badge for Admin/Manager
          if (_userRole == 'Admin' || _userRole == 'Manager')
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTierColor(_subscriptionTier),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _subscriptionTier,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _visibleScreens[_selectedIndex],
      ),
      // Only show bottom nav if more than 1 item
      bottomNavigationBar: _visibleMenuItems.length > 1 
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_visibleMenuItems.length, (index) {
                  final item = _visibleMenuItems[index];
                  final isSelected = _selectedIndex == index;
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onMenuTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.shade50
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item['icon'],
                              size: 24,
                              color: isSelected ? Colors.blue.shade800 : Colors.grey.shade600,
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _getLocalizedLabel(context, item['module']),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.blue.shade800 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            )
          : null, // Hide nav bar for single item (Staff)
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'ENTERPRISE': return Colors.purple;
      case 'PRO': return Colors.orange;
      default: return Colors.teal;
    }
  }

  String _getLocalizedLabel(BuildContext context, String module) {
    switch (module) {
      case 'ORDERS': return AppLocalizations.of(context)!.moduleOrders;
      case 'KITCHEN': return AppLocalizations.of(context)!.moduleOperations;
      case 'INVENTORY': return AppLocalizations.of(context)!.moduleInventory;
      case 'FINANCE': return AppLocalizations.of(context)!.moduleFinance;
      case 'REPORTS': return AppLocalizations.of(context)!.moduleReports;
      case 'SETTINGS': return AppLocalizations.of(context)!.moduleSettings;
      case 'ATTENDANCE': return AppLocalizations.of(context)!.moduleAttendance;
      default: return module;
    }
  }
}
