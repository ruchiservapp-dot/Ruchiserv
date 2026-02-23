// MODULE: OPERATIONS HUB (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Updated: 2025-12-14 | Features: Role-Based Access, Kitchen, Dispatch, My Attendance, Staff (Admin)
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import 'kitchen_screen.dart';
import 'dispatch_hub_screen.dart';
import 'staff_screen.dart';
import 'my_attendance_screen.dart';
import '../widgets/shimmer_loader.dart';

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
    String role = sp.getString('user_role') ?? sp.getString('last_role') ?? '';
    
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
          await sp.setString('last_role', role);
        }
      }
    }
    
    setState(() {
      _isAdmin = role.toLowerCase() == 'admin' || 
                 role.toLowerCase() == 'owner' ||
                 role.toLowerCase() == 'manager';
      _isLoading = false;
    });
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => screen, fullscreenDialog: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: ShimmerCardLoader());
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Subtle glowing orb background effect for Operations
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(isDark ? 0.15 : 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(isDark ? 0.1 : 0.05),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeader(isDark),
                      const SizedBox(height: 24),
                      _buildBentoGrid(context, isDark),
                      const SizedBox(height: 100), // padding for floating bottom bar
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          AppLocalizations.of(context)!.moduleOperations,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage daily activities and staff',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBentoGrid(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          // Mobile Layout: Stack vertically
          return Column(
            children: [
              _buildBentoCard(
                context,
                title: AppLocalizations.of(context)!.kitchenView,
                subtitle: 'Production & Recipes',
                icon: Icons.kitchen,
                color: Colors.orange,
                height: 120,
                isLarge: true,
                onTap: () => _navigateTo(const KitchenScreen()),
              ),
              const SizedBox(height: 12),
              _buildBentoCard(
                context,
                title: AppLocalizations.of(context)!.dispatchView,
                subtitle: 'Delivery & Logistics',
                icon: Icons.delivery_dining,
                color: Colors.green,
                height: 120,
                isLarge: true,
                onTap: () => _navigateTo(const DispatchScreen()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildBentoCard(
                      context,
                      title: AppLocalizations.of(context)!.attendanceTitle,
                      subtitle: AppLocalizations.of(context)!.punchInOut,
                      icon: Icons.fingerprint,
                      color: Colors.teal,
                      height: 130,
                      onTap: () => _navigateTo(const MyAttendanceScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isAdmin
                        ? _buildBentoCard(
                            context,
                            title: AppLocalizations.of(context)!.staffManagement,
                            subtitle: AppLocalizations.of(context)!.adminOnly,
                            icon: Icons.people,
                            color: Colors.blue,
                            height: 130,
                            onTap: () => _navigateTo(const StaffScreen()),
                          )
                        : _buildLockedCard(
                            context,
                            title: AppLocalizations.of(context)!.staffManagement,
                            subtitle: 'Locked',
                            icon: Icons.people,
                            height: 130,
                          ),
                  ),
                ],
              ),
            ],
          );
        }

        // Tablet/Desktop Layout
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: AppLocalizations.of(context)!.kitchenView,
                    subtitle: 'Production & Recipes',
                    icon: Icons.kitchen,
                    color: Colors.orange,
                    height: 140,
                    isLarge: true,
                    onTap: () => _navigateTo(const KitchenScreen()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: AppLocalizations.of(context)!.dispatchView,
                    subtitle: 'Delivery & Logistics',
                    icon: Icons.delivery_dining,
                    color: Colors.green,
                    height: 140,
                    isLarge: true,
                    onTap: () => _navigateTo(const DispatchScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: AppLocalizations.of(context)!.attendanceTitle,
                    subtitle: AppLocalizations.of(context)!.punchInOut,
                    icon: Icons.fingerprint,
                    color: Colors.teal,
                    height: 140,
                    isLarge: true,
                    onTap: () => _navigateTo(const MyAttendanceScreen()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _isAdmin
                      ? _buildBentoCard(
                          context,
                          title: AppLocalizations.of(context)!.staffManagement,
                          subtitle: AppLocalizations.of(context)!.adminOnly,
                          icon: Icons.people,
                          color: Colors.blue,
                          height: 140,
                          isLarge: true,
                          onTap: () => _navigateTo(const StaffScreen()),
                        )
                      : _buildLockedCard(
                          context,
                          title: AppLocalizations.of(context)!.staffManagement,
                          subtitle: 'Locked',
                          icon: Icons.people,
                          height: 140,
                          isLarge: true,
                        ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBentoCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double height,
    bool isLarge = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: isLarge 
                 ? _buildLargeLayout(title, subtitle, icon, color)
                 : _buildSmallLayout(title, subtitle, icon, color),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required double height,
    bool isLarge = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.restrictedToAdmins), backgroundColor: Colors.red),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              children: [
                isLarge 
                 ? _buildLargeLayout(title, subtitle, icon, Colors.grey)
                 : _buildSmallLayout(title, subtitle, icon, Colors.grey),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.lock, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeLayout(String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ],
    );
  }

  Widget _buildSmallLayout(String title, String subtitle, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter', height: 1.1),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}
