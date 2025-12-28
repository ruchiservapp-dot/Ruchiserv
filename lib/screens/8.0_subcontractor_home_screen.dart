// MODULE: SUBCONTRACTOR HOME SCREEN (v34)
// Features: Dashboard with active orders, calendar widget, ledger access
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '8.1_subcontractor_calendar_screen.dart';
import '8.2_subcontractor_order_detail_screen.dart';
import '8.3_subcontractor_ledger_screen.dart';

class SubcontractorHomeScreen extends StatefulWidget {
  const SubcontractorHomeScreen({super.key});

  @override
  State<SubcontractorHomeScreen> createState() => _SubcontractorHomeScreenState();
}

class _SubcontractorHomeScreenState extends State<SubcontractorHomeScreen> {
  bool _isLoading = true;
  int _subcontractorId = 0;
  String _subcontractorName = '';
  
  List<Map<String, dynamic>> _todayOrders = [];
  List<Map<String, dynamic>> _upcomingDays = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final sp = await SharedPreferences.getInstance();
    final mobile = sp.getString('last_mobile') ?? '';
    final firmId = sp.getString('last_firm') ?? '';
    
    final db = await DatabaseHelper().database;
    
    // Get subcontractor by mobile
    final subs = await db.rawQuery('''
      SELECT * FROM subcontractors WHERE mobile = ? AND firmId = ?
    ''', [mobile, firmId]);
    
    if (subs.isNotEmpty) {
      _subcontractorId = subs.first['id'] as int? ?? 0;
      _subcontractorName = subs.first['name']?.toString() ?? 'Subcontractor';
    }
    
    if (_subcontractorId > 0) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Today's orders (subcontracted dishes)
      final todayOrders = await db.rawQuery('''
        SELECT o.*, d.dishName, d.pax, d.category
        FROM orders o
        JOIN dishes d ON d.orderId = o.id
        WHERE d.isSubcontracted = 1 AND d.subcontractorId = ? AND o.date = ?
        ORDER BY o.time ASC
      ''', [_subcontractorId, today]);
      
      _todayOrders = List<Map<String, dynamic>>.from(todayOrders);
      
      // Upcoming 7 days summary
      List<Map<String, dynamic>> upcoming = [];
      for (int i = 1; i <= 7; i++) {
        final date = DateTime.now().add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        final count = await db.rawQuery('''
          SELECT COUNT(DISTINCT o.id) as orderCount, SUM(d.pax) as totalPax
          FROM orders o
          JOIN dishes d ON d.orderId = o.id
          WHERE d.isSubcontracted = 1 AND d.subcontractorId = ? AND o.date = ?
        ''', [_subcontractorId, dateStr]);
        
        if (count.isNotEmpty && (count.first['orderCount'] as int? ?? 0) > 0) {
          upcoming.add({
            'date': date,
            'orderCount': count.first['orderCount'],
            'totalPax': count.first['totalPax'],
          });
        }
      }
      _upcomingDays = upcoming;
      
      // Monthly summary
      final monthStart = DateFormat('yyyy-MM-01').format(DateTime.now());
      final summary = await db.rawQuery('''
        SELECT COUNT(DISTINCT o.id) as totalOrders, SUM(d.pax) as totalPax
        FROM orders o
        JOIN dishes d ON d.orderId = o.id
        WHERE d.isSubcontracted = 1 AND d.subcontractorId = ? AND o.date >= ?
      ''', [_subcontractorId, monthStart]);
      
      _summary = summary.isNotEmpty ? Map<String, dynamic>.from(summary.first) : {};
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 16),
              _buildQuickActions(),
              const SizedBox(height: 16),
              _buildTodaySection(),
              const SizedBox(height: 16),
              _buildUpcomingSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final totalOrders = (_summary['totalOrders'] as num?)?.toInt() ?? 0;
    final totalPax = (_summary['totalPax'] as num?)?.toInt() ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.purple.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(Icons.business, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                    Text(_subcontractorName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('$totalOrders', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('This Month Orders', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('$totalPax', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('Total Pax', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionCard('Calendar', Icons.calendar_month, Colors.blue, () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SubcontractorCalendarScreen(subcontractorId: _subcontractorId),
            )).then((_) => _loadData());
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard('Ledger', Icons.account_balance_wallet, Colors.green, () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SubcontractorLedgerScreen(subcontractorId: _subcontractorId, subcontractorName: _subcontractorName),
            ));
          }),
        ),
      ],
    );
  }

  Widget _actionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today's Orders", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_todayOrders.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 48, color: Colors.green.shade300),
                    const SizedBox(height: 8),
                    const Text('No orders for today'),
                  ],
                ),
              ),
            ),
          )
        else
          ...List.generate(_todayOrders.length, (i) => _buildOrderCard(_todayOrders[i])),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade100,
          child: Icon(Icons.restaurant, color: Colors.purple.shade700),
        ),
        title: Text(order['customerName'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${order['dishName']} • ${order['pax']} pax • ${order['time']}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => SubcontractorOrderDetailScreen(
            date: order['date'],
            subcontractorId: _subcontractorId,
          ),
        )),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upcoming (7 Days)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_upcomingDays.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('No upcoming orders', style: TextStyle(color: Colors.grey.shade600)),
              ),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _upcomingDays.length,
              itemBuilder: (ctx, i) {
                final day = _upcomingDays[i];
                final date = day['date'] as DateTime;
                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 8),
                  child: Card(
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SubcontractorOrderDetailScreen(
                          date: DateFormat('yyyy-MM-dd').format(date),
                          subcontractorId: _subcontractorId,
                        ),
                      )),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(DateFormat('EEE').format(date), style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                          Text('${date.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(DateFormat('MMM').format(date), style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${day['orderCount']}', style: TextStyle(fontSize: 10, color: Colors.purple.shade700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
