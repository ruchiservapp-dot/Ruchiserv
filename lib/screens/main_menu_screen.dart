import 'package:ruchiserv/core/app_logger.dart';
// Main Menu Screen - HIDDEN MODULES FOR UNAUTHORIZED USERS
// Only shows modules user is allowed to access
// Responsive: bottom nav on mobile/tablet, sidebar rail on desktop
import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/responsive_utils.dart';
import '../services/permission_service.dart';
import '../services/feature_gate_service.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

import 'home_dashboard_screen.dart';
import 'orders_calendar_screen.dart';
import 'operations_screen.dart';
import 'inventory_screen.dart';
import 'finance_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
// Portal screens for external user roles (v34)
import 'driver_home_screen.dart';
import 'subcontractor_home_screen.dart';
import 'supplier_home_screen.dart';
import 'reports/analytics_dashboard_screen.dart';
import '../widgets/cloud_sync_indicator.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isExternalPortal = false; // For Driver/Subcontractor/Supplier
  Widget? _portalScreen; // Dedicated portal for external users

  String _subscriptionTier = 'BASIC';
  String _userRole = 'Staff';

  // Only visible menu items (filtered by role)
  List<Map<String, dynamic>> _visibleMenuItems = [];
  List<Widget> _visibleScreens = [];

  // All possible menu items - My Attendance is accessed via Operations, not a standalone module
  final List<Map<String, dynamic>> _allMenuItems = [
    {
      'icon': Icons.dashboard_rounded,
      'label': 'Home',
      'module': 'HOME',
      'tier': 'BASIC'
    },
    {
      'icon': Icons.receipt_long,
      'label': 'Orders',
      'module': 'ORDERS',
      'tier': 'BASIC'
    },
    {
      'icon': Icons.inventory_2,
      'label': 'Inventory',
      'module': 'INVENTORY',
      'tier': 'BASIC'
    },
    {
      'icon': Icons.settings_suggest,
      'label': 'Operations',
      'module': 'KITCHEN',
      'tier': 'BASIC'
    },
    {
      'icon': Icons.account_balance_wallet,
      'label': 'Finance',
      'module': 'FINANCE',
      'tier': 'PRO'
    },
    {
      'icon': Icons.bar_chart_rounded,
      'label': 'Reports',
      'module': 'REPORTS',
      'tier': 'BASIC'
    },
    {
      'icon': Icons.insights,
      'label': 'Insights',
      'module': 'INSIGHTS',
      'tier': 'PRO'
    },
    {
      'icon': Icons.settings,
      'label': 'Settings',
      'module': 'SETTINGS',
      'tier': 'BASIC'
    },
  ];

  final List<Widget> _allScreens = const [
    HomeDashboardScreen(),
    OrderCalendarScreen(),
    InventoryScreen(),
    OperationsScreen(),
    FinanceScreen(),
    ReportsScreen(),
    AnalyticsDashboardScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    AppLogger.info('MainMenuDebug: initState started');
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    AppLogger.info('MainMenuDebug: _loadPermissions started');
    try {
      final role = await PermissionService.instance.getUserRole();
      AppLogger.info('MainMenuDebug: Role found: $role');
      final allowedModules =
          await PermissionService.instance.getAllowedModules();
      AppLogger.info('MainMenuDebug: Modules: ${allowedModules.length}');
      final tier = await FeatureGateService.instance.getCurrentTier();
      AppLogger.info('MainMenuDebug: Tier: $tier');

      // Check for external portal users (Driver, Subcontractor, Supplier)
      // These users get a dedicated single-screen portal instead of the standard menu
      final roleLower = role.toLowerCase();
      if (roleLower == 'driver') {
        AppLogger.info('MainMenuDebug: User is DRIVER. Setting portal screen.');
        setState(() {
          _userRole = role;
          _isExternalPortal = true;
          _portalScreen = const DriverHomeScreen();
          _isLoading = false;
        });
        return;
      } else if (roleLower == 'subcontractor' || roleLower == 'vendor') {
        setState(() {
          _userRole = role;
          _isExternalPortal = true;
          _portalScreen = const SubcontractorHomeScreen();
          _isLoading = false;
        });
        return;
      } else if (roleLower == 'supplier') {
        setState(() {
          _userRole = role;
          _isExternalPortal = true;
          _portalScreen = const SupplierHomeScreen();
          _isLoading = false;
        });
        return;
      }

      // Standard menu for Admin, Manager, Staff
      // Filter menu items based on Admin-assigned permissions for ALL roles
      List<Map<String, dynamic>> visible = [];
      List<Widget> screens = [];

      // For ALL roles (including Staff, Driver, Vendor, Subcontractor),
      // filter based on module access assigned by Admin
      for (int i = 0; i < _allMenuItems.length; i++) {
        final item = _allMenuItems[i];
        final module = item['module'] as String;

        // Check if user can access this module
        bool hasAccess = module == 'HOME' ||
            role == 'Admin' ||
            allowedModules.contains(module) ||
            allowedModules.contains('ALL');

        // Check tier requirements
        final requiredTier = item['tier'] as String;
        bool hasTier = role == 'Admin' || _checkTierAccess(tier, requiredTier);

        if (hasAccess && hasTier) {
          visible.add(item);
          screens.add(_allScreens[i]);
        }
      }

      // Fallback: If nothing visible, show My Attendance for non-Admin roles
      // or Orders for Admin
      if (visible.isEmpty) {
        if (role == 'Admin') {
          visible.add(_allMenuItems[0]); // Orders
          screens.add(_allScreens[0]);
        } else {
          // Show Operations as minimum for Staff (My Attendance is inside Operations)
          visible.add(_allMenuItems[2]); // Operations
          screens.add(_allScreens[2]);
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
      AppLogger.info('MainMenuDebug: _loadPermissions complete');
    } catch (e, stack) {
      AppLogger.error('MainMenuDebug error: $e', stack);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _checkTierAccess(String currentTier, String requiredTier) {
    if (currentTier == 'ENTERPRISE') return true;
    if (currentTier == 'PRO' &&
        (requiredTier == 'PRO' || requiredTier == 'BASIC')) return true;
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

    // External portal mode (Driver/Subcontractor/Supplier)
    if (_isExternalPortal && _portalScreen != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('RuchiServ • $_userRole'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showLogoutDialog(),
              tooltip: 'Logout',
            ),
          ],
        ),
        body: _portalScreen,
      );
    }

    // Handle empty state for standard menu
    if (_visibleMenuItems.isEmpty || _visibleScreens.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).noModulesAvailable),
              Text(AppLocalizations.of(context).contactAdministrator,
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final moduleName = _getLocalizedLabel(
        context, _visibleMenuItems[_selectedIndex]['module']);
    final useSideNav = Responsive.useSideNav(context);

    // ── Shared AppBar ────────────────────────────────────────────────────────
    final appBar = AppBar(
      elevation: 0,
      title: Text(
        moduleName,
        style:
            const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                      color: Colors.white),
                ),
              ),
            ),
          ),
        const CloudSyncIndicator(),
        // Logout button visible in AppBar on desktop (no bottom nav)
        if (useSideNav)
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _showLogoutDialog,
          ),
      ],
    );

    // ── Desktop: NavigationRail sidebar ─────────────────────────────────────
    if (useSideNav) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onMenuTap,
              labelType: NavigationRailLabelType.all,
              backgroundColor: theme.cardColor,
              selectedIconTheme: IconThemeData(
                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade800),
              selectedLabelTextStyle: TextStyle(
                color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedIconTheme: IconThemeData(
                  color: isDark ? Colors.white54 : Colors.grey.shade600),
              unselectedLabelTextStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 12),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.restaurant,
                      color: Colors.white, size: 22),
                ),
              ),
              destinations: _visibleMenuItems.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item['icon']),
                  label: Text(_getLocalizedLabel(context, item['module'])),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _visibleScreens[_selectedIndex],
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile / Tablet: Bottom navigation bar ───────────────────────────────
    return Scaffold(
      extendBody: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: appBar,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _visibleScreens[_selectedIndex],
      ),
      bottomNavigationBar: _visibleMenuItems.length > 1
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                          color: isDark
                              ? Colors.black54
                              : Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children:
                            List.generate(_visibleMenuItems.length, (index) {
                          final item = _visibleMenuItems[index];
                          final isSelected = _selectedIndex == index;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _onMenuTap(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark
                                          ? Colors.blue.withOpacity(0.15)
                                          : Colors.blue.shade50)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item['icon'],
                                      size: 26,
                                      color: isSelected
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blueAccent)
                                          : (isDark
                                              ? Colors.white54
                                              : Colors.grey.shade400),
                                    ),
                                    if (isSelected) const SizedBox(height: 4),
                                    if (isSelected)
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _getLocalizedLabel(
                                              context, item['module']),
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.blue.shade300
                                                : Colors.blueAccent,
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
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to login screen
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'ENTERPRISE':
        return Colors.purple;
      case 'PRO':
        return Colors.orange;
      default:
        return Colors.teal;
    }
  }

  String _getLocalizedLabel(BuildContext context, String module) {
    switch (module) {
      case 'HOME':
        return 'Dashboard';
      case 'ORDERS':
        return AppLocalizations.of(context).moduleOrders;
      case 'KITCHEN':
        return AppLocalizations.of(context).moduleOperations;
      case 'INVENTORY':
        return AppLocalizations.of(context).moduleInventory;
      case 'FINANCE':
        return AppLocalizations.of(context).moduleFinance;
      case 'REPORTS':
        return AppLocalizations.of(context).moduleReports;
      case 'INSIGHTS':
        return 'Insights';
      case 'SETTINGS':
        return AppLocalizations.of(context).moduleSettings;
      case 'ATTENDANCE':
        return AppLocalizations.of(context).moduleAttendance;
      default:
        return module;
    }
  }
}
