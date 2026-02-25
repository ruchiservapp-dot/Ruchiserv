// MODULE: INVENTORY HUB
// Last Updated: 2025-12-14 | Features: Navigation tiles for Inventory sub-modules (6 modules)
import 'package:flutter/material.dart';
import 'ingredients_screen.dart';
import 'bom_screen.dart';
import 'mrp_hub_screen.dart';
import 'supplier_screen.dart';
import 'subcontractor_screen.dart';
import 'utensils_screen.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

// MODULE: INVENTORY HUB (Lustre UI Modernization)
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/settings_provider.dart';
import '../db/database_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String? _firmId;
  int _activeIngredients = 0;
  int _activeSuppliers = 0;
  int _pendingPOs = 0;
  int _draftMrpRuns = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final settings = context.read<SettingsProvider>();
      _firmId = settings.firmId;

      if (_firmId != null) {
        final db = await DatabaseHelper().database;

        // Fetch Ingredients Count
        final ingResult = await db.rawQuery(
            'SELECT COUNT(*) as count FROM ingredients_master WHERE firmId = ? AND isActive = 1',
            [_firmId]);
        _activeIngredients = (ingResult.first['count'] as int?) ?? 0;

        // Fetch Suppliers Count
        final supResult = await db.rawQuery(
            'SELECT COUNT(*) as count FROM suppliers WHERE firmId = ? AND isActive = 1',
            [_firmId]);
        _activeSuppliers = (supResult.first['count'] as int?) ?? 0;

        // Fetch Pending POs
        final poResult = await db.rawQuery(
            'SELECT COUNT(*) as count FROM purchase_orders WHERE firmId = ? AND status = "SENT"',
            [_firmId]);
        _pendingPOs = (poResult.first['count'] as int?) ?? 0;

        // Fetch MRP Drafts
        final mrpResult = await db.rawQuery(
            'SELECT COUNT(*) as count FROM mrp_runs WHERE firmId = ? AND status = "DRAFT"',
            [_firmId]);
        _draftMrpRuns = (mrpResult.first['count'] as int?) ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading inventory stats: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    if (settings.firmId != null && settings.firmId != _firmId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboardStats());
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Minimal background mesh gradient feel
      body: Stack(
        children: [
          // Background mesh elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(isDark ? 0.15 : 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(isDark ? 0.1 : 0.05),
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadDashboardStats,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHealthStrip(isDark),
                        const SizedBox(height: 20),
                        _buildBentoGrid(context, isDark),
                        const SizedBox(height: 100), // padding for bottom nav
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStrip(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHealthMetric(
                  'Ingredients',
                  _isLoading ? '-' : '$_activeIngredients',
                  Icons.restaurant_menu,
                  Colors.green),
              Container(
                  width: 1,
                  height: 40,
                  color: isDark ? Colors.white24 : Colors.black26),
              _buildHealthMetric(
                  'Suppliers',
                  _isLoading ? '-' : '$_activeSuppliers',
                  Icons.local_shipping,
                  Colors.teal),
              Container(
                  width: 1,
                  height: 40,
                  color: isDark ? Colors.white24 : Colors.black26),
              _buildHealthMetric(
                  'Pending POs',
                  _isLoading ? '-' : '$_pendingPOs',
                  Icons.receipt_long,
                  _pendingPOs > 0 ? Colors.orange : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthMetric(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
              fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBentoGrid(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          // Mobile Layout: Stack everything vertically
          return Column(
            children: [
              _buildBentoCard(
                context,
                title: 'MRP & Planning',
                subtitle: _isLoading
                    ? 'Loading...'
                    : (_draftMrpRuns > 0
                        ? '$_draftMrpRuns Drafts Pending'
                        : 'All clear. Plan next batch!'),
                icon: Icons.analytics,
                color: Colors.blueAccent,
                height: 120, // Slightly shorter for mobile
                isLarge: true,
                onTap: () => _navigateTo(const MrpHubScreen()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildBentoCard(
                      context,
                      title: AppLocalizations.of(context).ingredients,
                      subtitle: 'Master List',
                      icon: Icons.grass, // Eco-friendly ingredient feel
                      color: Colors.green,
                      height: 110,
                      onTap: () => _navigateTo(const IngredientsScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBentoCard(
                      context,
                      title: AppLocalizations.of(context).bom,
                      subtitle: 'Recipe Math',
                      icon: Icons.account_tree,
                      color: Colors.orange,
                      height: 110,
                      onTap: () => _navigateTo(const BomScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildBentoCard(
                      context,
                      title: 'Vendors',
                      subtitle: 'Manage',
                      icon: Icons.storefront,
                      color: Colors.teal,
                      height: 100,
                      onTap: () => _navigateTo(const SupplierScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBentoCard(
                      context,
                      title: 'Kitchens',
                      subtitle: 'Sub-cons',
                      icon: Icons.outdoor_grill,
                      color: Colors.indigo,
                      height: 100,
                      onTap: () => _navigateTo(const SubcontractorScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildBentoCard(
                context,
                title: 'Utensils',
                subtitle: 'Tracking',
                icon: Icons.soup_kitchen,
                color: Colors.purple,
                height: 100,
                isLarge: true, // Make utensils full width on mobile
                onTap: () => _navigateTo(const UtensilsScreen()),
              ),
            ],
          );
        }

        // Tablet/Desktop Layout: Original Grid
        return Column(
          children: [
            // Top Row: large MRP card
            Row(
              children: [
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: 'MRP & Planning',
                    subtitle: _isLoading
                        ? 'Loading...'
                        : (_draftMrpRuns > 0
                            ? '$_draftMrpRuns Drafts Pending'
                            : 'All clear. Plan next batch!'),
                    icon: Icons.analytics,
                    color: Colors.blueAccent,
                    height: 140,
                    isLarge: true,
                    onTap: () => _navigateTo(const MrpHubScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Middle Row: Ingredients & BOM
            Row(
              children: [
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: AppLocalizations.of(context).ingredients,
                    subtitle: 'Master List',
                    icon: Icons.grass,
                    color: Colors.green,
                    height: 120,
                    onTap: () => _navigateTo(const IngredientsScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: AppLocalizations.of(context).bom,
                    subtitle: 'Recipe Math',
                    icon: Icons.account_tree,
                    color: Colors.orange,
                    height: 120,
                    onTap: () => _navigateTo(const BomScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom Row: Suppliers, Subcontractors, Utensils
            Row(
              children: [
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: 'Vendors',
                    subtitle: 'Manage',
                    icon: Icons.storefront,
                    color: Colors.teal,
                    height: 110,
                    onTap: () => _navigateTo(const SupplierScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: 'Kitchens',
                    subtitle: 'Sub-cons',
                    icon: Icons.outdoor_grill,
                    color: Colors.indigo,
                    height: 110,
                    onTap: () => _navigateTo(const SubcontractorScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: 'Utensils',
                    subtitle: 'Tracking',
                    icon: Icons.soup_kitchen,
                    color: Colors.purple,
                    height: 110,
                    onTap: () => _navigateTo(const UtensilsScreen()),
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
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1),
        boxShadow: isDark
            ? []
            : [
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

  Widget _buildLargeLayout(
      String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Subtle background icon for large cards
        Icon(Icons.arrow_forward_ios,
            color: Colors.grey.withOpacity(0.3), size: 20),
      ],
    );
  }

  Widget _buildSmallLayout(
      String title, String subtitle, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start, // Changed from spaceBetween
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8), // Added spacing
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _navigateTo(Widget screen) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => screen, fullscreenDialog: true),
    );
    // Refresh stats when coming back
    _loadDashboardStats();
  }
}
