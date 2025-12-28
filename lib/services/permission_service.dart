// Permission Service - Role-Based Access Control (RBAC)
// Manages user permissions and module access based on role
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

class PermissionService {
  static PermissionService? _instance;
  static PermissionService get instance => _instance ??= PermissionService._();
  PermissionService._();

  // Cached permissions
  String? _cachedRole;
  String? _cachedPermissions;
  List<String>? _cachedModules;
  bool? _cachedShowRates;

  // Role definitions with default permissions
  static const rolePermissions = {
    'Admin': 'ALL',
    'Manager': 'ORDERS,CALENDAR,KITCHEN,DISPATCH,INVENTORY,REPORTS,STAFF',
    'Accountant': 'FINANCE,REPORTS,ORDERS',
    'Staff': 'ORDERS,KITCHEN,DISPATCH',
    'Driver': 'DISPATCH',
    'Vendor': 'ORDERS',
    'Subcontractor': 'KITCHEN',
  };

  // Module definitions
  static const allModules = [
    'ORDERS', 'CALENDAR', 'KITCHEN', 'DISPATCH', 'INVENTORY',
    'FINANCE', 'REPORTS', 'SETTINGS', 'STAFF', 'SUBSCRIPTION', 'ATTENDANCE',
  ];

  /// Initialize permissions after login
  Future<void> initialize() async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm');
    final mobile = sp.getString('last_mobile');
    
    if (firmId == null || mobile == null) return;
    
    final db = await DatabaseHelper().database;
    final users = await db.query('users', 
      where: 'firmId = ? AND mobile = ?', 
      whereArgs: [firmId, mobile],
      limit: 1,
    );
    
    if (users.isNotEmpty) {
      final user = users.first;
      _cachedRole = user['role'] as String? ?? 'Staff';
      _cachedPermissions = user['permissions'] as String?;
      _cachedShowRates = (user['showRates'] as int?) == 1;
      
      // Get module access - use custom if set, otherwise use role defaults
      final moduleAccess = user['moduleAccess'] as String?;
      if (moduleAccess != null && moduleAccess.isNotEmpty) {
        _cachedModules = moduleAccess.split(',');
      } else {
        final rolePerms = rolePermissions[_cachedRole] ?? 'ORDERS';
        _cachedModules = rolePerms == 'ALL' ? allModules : rolePerms.split(',');
      }
      
      // Cache in SharedPreferences for quick access
      await sp.setString('user_role', _cachedRole!);
      await sp.setString('user_permissions', _cachedPermissions ?? '');
      await sp.setBool('show_rates', _cachedShowRates ?? true);
      await sp.setStringList('allowed_modules', _cachedModules!);
    }
  }

  /// Clear cached permissions on logout
  Future<void> clear() async {
    _cachedRole = null;
    _cachedPermissions = null;
    _cachedModules = null;
    _cachedShowRates = null;
    
    final sp = await SharedPreferences.getInstance();
    await sp.remove('user_role');
    await sp.remove('user_permissions');
    await sp.remove('show_rates');
    await sp.remove('allowed_modules');
  }

  /// Get current user's role
  Future<String> getUserRole() async {
    if (_cachedRole != null) return _cachedRole!;
    final sp = await SharedPreferences.getInstance();
    return sp.getString('user_role') ?? 'Staff';
  }

  /// Check if user is Admin
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'Admin';
  }

  /// Check if current user can access a module
  Future<bool> canAccess(String module) async {
    final role = await getUserRole();
    if (role == 'Admin') return true;
    
    if (_cachedModules != null) {
      return _cachedModules!.contains(module);
    }
    
    final sp = await SharedPreferences.getInstance();
    final modules = sp.getStringList('allowed_modules') ?? [];
    return modules.contains(module);
  }

  /// Check if current user can write/edit (not read-only)
  Future<bool> canWrite(String module) async {
    final role = await getUserRole();
    if (role == 'Admin' || role == 'Manager') return true;
    if (role == 'Staff' || role == 'Driver') return false; // Read-only
    return canAccess(module);
  }

  /// Check if current user can view rates/costs
  Future<bool> canViewRates() async {
    final role = await getUserRole();
    if (role == 'Admin' || role == 'Manager' || role == 'Accountant') return true;
    
    if (_cachedShowRates != null) return _cachedShowRates!;
    
    final sp = await SharedPreferences.getInstance();
    return sp.getBool('show_rates') ?? false;
  }

  // Roles allowed to access financial reports (Balance Sheet, Cash Flow, P&L)
  static const financeReportRoles = ['Admin', 'Manager', 'Accountant'];

  /// Check if current user can access financial reports
  /// (Balance Sheet, Cash Flow, P&L - restricted to Owner/Manager/Accountant)
  Future<bool> canAccessFinanceReports() async {
    final role = await getUserRole();
    return financeReportRoles.contains(role);
  }


  /// Get list of allowed modules for current user
  Future<List<String>> getAllowedModules() async {
    if (_cachedModules != null) return _cachedModules!;
    
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList('allowed_modules') ?? [];
  }

  /// Get permissions string for a role (for User Management)
  static String getDefaultPermissions(String role) {
    return rolePermissions[role] ?? 'ORDERS';
  }
}
