import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../services/cloud_sync_service.dart';
import 'reports/analytics_dashboard_screen.dart';
import 'add_order_screen.dart';
import 'mrp_run_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  String? _firmId;
  String _userName = 'User';

  // KPIs
  int _activeOrders = 0;
  double _todayRevenue = 0.0;
  int _pendingSyncs = 0;
  int _lowStockItems = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final sp = await SharedPreferences.getInstance();
      _firmId = sp.getString('last_firm');
      _userName = sp.getString('user_name') ?? 'Admin';

      if (_firmId != null) {
        final db = await DatabaseHelper().database;
        final today = DateTime.now().toIso8601String().substring(0, 10);

        // 1. Active Orders (Not Delivery/Cancelled)
        final ordersRes = await db.rawQuery(
            'SELECT COUNT(*) as count FROM orders WHERE firmId = ? AND isCancelled = 0 AND dispatchStatus != \'DELIVERED\'',
            [_firmId]);
        _activeOrders = Sqflite.firstIntValue(ordersRes) ?? 0;

        // 2. Today's Revenue
        final revRes = await db.rawQuery(
            'SELECT SUM(grandTotal) as total FROM orders WHERE firmId = ? AND isCancelled = 0 AND date LIKE ?',
            [_firmId, '$today%']);
        _todayRevenue = (revRes.first['total'] as num?)?.toDouble() ?? 0.0;

        // 3. Pending Syncs
        final syncRes =
            await db.rawQuery('SELECT COUNT(*) as count FROM pending_sync');
        _pendingSyncs = Sqflite.firstIntValue(syncRes) ?? 0;

        // 4. Low Stock / Out of Stock
        final stockRes = await db.rawQuery(
            'SELECT COUNT(*) as count FROM purchase_orders WHERE firmId = ? AND status = \'SENT\'',
            [_firmId]);
        _lowStockItems = Sqflite.firstIntValue(stockRes) ?? 0;
      }
    } catch (e) {
      debugPrint('Dash Error: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Mesh
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.indigo.withOpacity(isDark ? 0.15 : 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withOpacity(isDark ? 0.1 : 0.05),
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildGreeting(isDark),
                        const SizedBox(height: 24),
                        _buildMainMetrics(isDark),
                        const SizedBox(height: 24),
                        const Text(
                          'Command Center',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildBentoGrid(context, isDark),
                        const SizedBox(height: 100),
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

  Widget _buildGreeting(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $_userName',
          style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Overview Dashboard',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
        ),
      ],
    );
  }

  Widget _buildMainMetrics(bool isDark) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Container(
      padding: const EdgeInsets.all(20),
      // Glassmorphism wrapper
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Today\'s Revenue',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.white70,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.trending_up,
                            color: Colors.greenAccent, size: 14),
                        SizedBox(width: 4),
                        Text(
                          ' Live',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isLoading ? '...' : currencyFormat.format(_todayRevenue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              fontFamily: 'Inter',
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGrid(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: _buildMetricCard('Active Orders', '$_activeOrders',
                          Icons.restaurant, Colors.orange, isDark)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildMetricCard(
                          'Pending Sync',
                          '$_pendingSyncs',
                          Icons.cloud_sync,
                          _pendingSyncs > 0 ? Colors.redAccent : Colors.blue,
                          isDark)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildMetricCard(
                          'Low Stock',
                          '$_lowStockItems items',
                          Icons.inventory_2,
                          Colors.purple,
                          isDark)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildShortcutCard(
                        'Create Order', Icons.add_circle, Colors.teal, isDark,
                        onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AddOrderScreen(date: DateTime.now())));
                    }),
                  ),
                ],
              ),
            ],
          );
        }

        // Desktop Layout
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _buildMetricCard(
                              'Active Orders',
                              '$_activeOrders',
                              Icons.restaurant,
                              Colors.orange,
                              isDark)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildMetricCard(
                              'Pending Sync',
                              '$_pendingSyncs',
                              Icons.cloud_sync,
                              _pendingSyncs > 0
                                  ? Colors.redAccent
                                  : Colors.blue,
                              isDark)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _buildMetricCard(
                              'Low Stock',
                              '$_lowStockItems items',
                              Icons.inventory_2,
                              Colors.purple,
                              isDark)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildShortcutCard('Create Order',
                            Icons.add_circle, Colors.teal, isDark, onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      AddOrderScreen(date: DateTime.now())));
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('Quick Actions',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _listTileAction(
                        'Run End of Day', Icons.nightlight_round, isDark,
                        onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AnalyticsDashboardScreen()));
                    }),
                    const Divider(),
                    _listTileAction('Run MRP Batch', Icons.analytics, isDark,
                        onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MrpRunScreen()));
                    }),
                    const Divider(),
                    _listTileAction('Sync All Data', Icons.sync, isDark,
                        onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Cloud Sync Started...')));
                      await CloudSyncService().processPendingSync();
                      await CloudSyncService().fullSyncFromCloud();
                      _loadDashboardData();
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _listTileAction(String title, IconData icon, bool isDark,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 100 || constraints.maxWidth < 140;
        final cardPadding = compact ? 8.0 : 16.0;
        final iconPadding = compact ? 5.0 : 8.0;
        final iconSize = compact ? 16.0 : 20.0;
        final valueFontSize = compact ? 16.0 : 22.0;
        final titleFontSize = compact ? 10.0 : 12.0;

        return Container(
          padding: EdgeInsets.all(cardPadding),
          constraints: const BoxConstraints(minHeight: 88),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: iconSize),
              ),
              SizedBox(height: compact ? 4 : 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _isLoading ? '-' : value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: titleFontSize,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShortcutCard(
      String title, IconData icon, Color color, bool isDark,
      {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 120,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 32),
            Text(title,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
