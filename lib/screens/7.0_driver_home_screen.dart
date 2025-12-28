// MODULE: DRIVER HOME SCREEN (v34)
// Features: Driver dashboard with pending assignments, active dispatch, earnings summary
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '7.1_driver_assignment_screen.dart';
import '7.2_driver_dispatch_detail_screen.dart';
import '7.3_driver_active_dispatch_screen.dart';
import '7.5_driver_earnings_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isLoading = true;
  int _driverId = 0;
  String _driverName = '';
  
  // Data
  List<Map<String, dynamic>> _pendingAssignments = [];
  Map<String, dynamic>? _activeDispatch;
  Map<String, dynamic> _todayStats = {};
  Map<String, dynamic> _earningsSummary = {};

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    setState(() => _isLoading = true);
    
    final sp = await SharedPreferences.getInstance();
    final mobile = sp.getString('last_mobile') ?? '';
    final firmId = sp.getString('last_firm') ?? '';
    
    final db = await DatabaseHelper().database;
    
    // Get driver ID from users table (linked by mobile)
    final users = await db.query('users', 
      where: 'mobile = ? AND firmId = ?', 
      whereArgs: [mobile, firmId],
    );
    
    if (users.isNotEmpty) {
      _driverId = users.first['id'] as int? ?? 0;
      _driverName = users.first['name']?.toString() ?? 'Driver';
    }
    
    if (_driverId > 0) {
      await _loadDispatchData();
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadDispatchData() async {
    final db = await DatabaseHelper().database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // 1. Pending Assignments (PENDING status, assigned to this driver)
    final pending = await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date, o.time, o.totalPax, o.mobile as customerMobile,
             (SELECT COUNT(*) FROM dishes WHERE orderId = o.id) as dishCount
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      WHERE d.driverId = ? AND d.assignmentStatus = 'PENDING'
      ORDER BY o.date ASC, o.time ASC
    ''', [_driverId]);
    
    // 2. Active Dispatch (ACCEPTED, in progress)
    final active = await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date, o.time, o.totalPax, o.mobile as customerMobile,
             v.vehicleNo, v.vehicleType
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      LEFT JOIN vehicles v ON v.id = d.vehicleId
      WHERE d.driverId = ? AND d.assignmentStatus = 'ACCEPTED' 
        AND d.dispatchStatus IN ('PENDING', 'LOADING', 'DISPATCHED', 'DELIVERED')
      ORDER BY d.dispatchTime DESC
      LIMIT 1
    ''', [_driverId]);
    
    // 3. Today's Stats
    final todayCompleted = await db.rawQuery('''
      SELECT COUNT(*) as count, 
             COALESCE(SUM(kmForward + COALESCE(kmReturn, 0)), 0) as totalKm,
             COALESCE(SUM(driverShare), 0) as earnings
      FROM dispatches
      WHERE driverId = ? AND DATE(dispatchTime) = ?
        AND dispatchStatus IN ('DELIVERED', 'COMPLETED')
    ''', [_driverId, today]);
    
    // 4. Monthly Earnings Summary
    final monthStart = DateFormat('yyyy-MM-01').format(DateTime.now());
    final monthEarnings = await db.rawQuery('''
      SELECT COALESCE(SUM(driverShare), 0) as monthEarnings,
             COALESCE(SUM(kmForward + COALESCE(kmReturn, 0)), 0) as monthKm,
             COUNT(*) as tripCount,
             SUM(CASE WHEN isPaid = 0 THEN driverShare ELSE 0 END) as pendingAmount
      FROM dispatches
      WHERE driverId = ? AND DATE(dispatchTime) >= ?
        AND dispatchStatus IN ('DELIVERED', 'COMPLETED')
    ''', [_driverId, monthStart]);
    
    setState(() {
      _pendingAssignments = List<Map<String, dynamic>>.from(pending);
      _activeDispatch = active.isNotEmpty ? Map<String, dynamic>.from(active.first) : null;
      _todayStats = todayCompleted.isNotEmpty ? Map<String, dynamic>.from(todayCompleted.first) : {};
      _earningsSummary = monthEarnings.isNotEmpty ? Map<String, dynamic>.from(monthEarnings.first) : {};
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
      body: RefreshIndicator(
        onRefresh: _loadDispatchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              _buildWelcomeCard(),
              const SizedBox(height: 16),
              
              // Active Dispatch (if any)
              if (_activeDispatch != null) ...[
                _buildActiveDispatchCard(),
                const SizedBox(height: 16),
              ],
              
              // Today's Stats
              _buildTodayStatsCard(),
              const SizedBox(height: 16),
              
              // Pending Assignments
              _buildPendingAssignmentsSection(),
              const SizedBox(height: 16),
              
              // Monthly Earnings Card
              _buildEarningsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final now = DateTime.now();
    String greeting = 'Good Morning';
    if (now.hour >= 12 && now.hour < 17) greeting = 'Good Afternoon';
    else if (now.hour >= 17) greeting = 'Good Evening';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(Icons.person, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                Text(_driverName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(DateFormat('EEEE, MMM d').format(DateTime.now()), 
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('${_pendingAssignments.length}', 
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Pending', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDispatchCard() {
    final d = _activeDispatch!;
    final status = d['dispatchStatus'] ?? 'PENDING';
    
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.hourglass_empty;
    String statusText = 'Loading';
    
    switch (status) {
      case 'DISPATCHED':
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping;
        statusText = 'In Transit';
        break;
      case 'DELIVERED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Delivered';
        break;
      case 'RETURNING':
        statusColor = Colors.purple;
        statusIcon = Icons.assignment_return;
        statusText = 'Returning';
        break;
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DriverActiveDispatchScreen(dispatch: d)),
        ).then((_) => _loadDispatchData()),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ACTIVE DISPATCH', 
                          style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        Text(d['customerName'] ?? 'Customer', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(statusText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildDispatchInfo(Icons.location_on, d['location'] ?? 'N/A'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDispatchInfo(Icons.access_time, d['time'] ?? 'N/A'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDispatchInfo(Icons.local_shipping, d['vehicleNo'] ?? 'N/A'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDispatchInfo(Icons.people, '${d['totalPax'] ?? 0} Pax'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => DriverActiveDispatchScreen(dispatch: d)),
                  ).then((_) => _loadDispatchData()),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDispatchInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildTodayStatsCard() {
    final completed = (_todayStats['count'] as num?)?.toInt() ?? 0;
    final totalKm = (_todayStats['totalKm'] as num?)?.toDouble() ?? 0;
    final earnings = (_todayStats['earnings'] as num?)?.toDouble() ?? 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today, color: Colors.indigo, size: 20),
                const SizedBox(width: 8),
                const Text("Today's Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('$completed', 'Trips', Icons.local_shipping, Colors.blue),
                _buildStatItem('${totalKm.toStringAsFixed(1)} km', 'Distance', Icons.route, Colors.orange),
                _buildStatItem('₹${earnings.toStringAsFixed(0)}', 'Earned', Icons.currency_rupee, Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    );
  }

  Widget _buildPendingAssignmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Pending Assignments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (_pendingAssignments.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DriverAssignmentScreen()),
                ).then((_) => _loadDispatchData()),
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_pendingAssignments.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 48, color: Colors.green.shade300),
                    const SizedBox(height: 8),
                    const Text('No pending assignments', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          )
        else
          ...List.generate(
            _pendingAssignments.length > 3 ? 3 : _pendingAssignments.length,
            (i) => _buildAssignmentCard(_pendingAssignments[i]),
          ),
      ],
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: Icon(Icons.delivery_dining, color: Colors.orange.shade700),
        ),
        title: Text(assignment['customerName'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${assignment['date']} • ${assignment['time']} • ${assignment['dishCount'] ?? 0} dishes'),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DriverDispatchDetailScreen(dispatch: assignment)),
        ).then((_) => _loadDispatchData()),
      ),
    );
  }

  Widget _buildEarningsCard() {
    final monthEarnings = (_earningsSummary['monthEarnings'] as num?)?.toDouble() ?? 0;
    final monthKm = (_earningsSummary['monthKm'] as num?)?.toDouble() ?? 0;
    final tripCount = (_earningsSummary['tripCount'] as num?)?.toInt() ?? 0;
    final pendingAmount = (_earningsSummary['pendingAmount'] as num?)?.toDouble() ?? 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DriverEarningsScreen(driverId: _driverId)),
        ).then((_) => _loadDispatchData()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Text('Monthly Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${monthEarnings.toStringAsFixed(0)}', 
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                        Text('$tripCount trips • ${monthKm.toStringAsFixed(0)} km', 
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (pendingAmount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text('₹${pendingAmount.toStringAsFixed(0)}', 
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                          Text('Pending', style: TextStyle(fontSize: 10, color: Colors.orange.shade600)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
