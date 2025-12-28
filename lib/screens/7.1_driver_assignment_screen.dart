// MODULE: DRIVER ASSIGNMENT SCREEN (v34)
// Features: List pending dispatch assignments, accept/reject functionality
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '7.2_driver_dispatch_detail_screen.dart';

class DriverAssignmentScreen extends StatefulWidget {
  const DriverAssignmentScreen({super.key});

  @override
  State<DriverAssignmentScreen> createState() => _DriverAssignmentScreenState();
}

class _DriverAssignmentScreenState extends State<DriverAssignmentScreen> {
  bool _isLoading = true;
  int _driverId = 0;
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);
    
    final sp = await SharedPreferences.getInstance();
    final mobile = sp.getString('last_mobile') ?? '';
    final firmId = sp.getString('last_firm') ?? '';
    
    final db = await DatabaseHelper().database;
    
    // Get driver ID
    final users = await db.query('users', 
      where: 'mobile = ? AND firmId = ?', 
      whereArgs: [mobile, firmId],
    );
    
    if (users.isNotEmpty) {
      _driverId = users.first['id'] as int? ?? 0;
    }
    
    if (_driverId > 0) {
      final assignments = await db.rawQuery('''
        SELECT d.*, o.customerName, o.location, o.date, o.time, o.totalPax, 
               o.mobile as customerMobile, o.mealType, o.foodType,
               v.vehicleNo, v.vehicleType,
               (SELECT COUNT(*) FROM dishes WHERE orderId = o.id) as dishCount
        FROM dispatches d
        JOIN orders o ON o.id = d.orderId
        LEFT JOIN vehicles v ON v.id = d.vehicleId
        WHERE d.driverId = ? AND d.assignmentStatus = 'PENDING'
        ORDER BY o.date ASC, o.time ASC
      ''', [_driverId]);
      
      setState(() {
        _assignments = List<Map<String, dynamic>>.from(assignments);
      });
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _acceptAssignment(Map<String, dynamic> dispatch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Assignment?'),
        content: Text('Accept delivery to ${dispatch['customerName']} on ${dispatch['date']} at ${dispatch['time']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final db = await DatabaseHelper().database;
      await db.update('dispatches', {
        'assignmentStatus': 'ACCEPTED',
        'acceptedAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [dispatch['id']]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment accepted!'), backgroundColor: Colors.green),
      );
      _loadAssignments();
    }
  }

  Future<void> _rejectAssignment(Map<String, dynamic> dispatch) async {
    final TextEditingController reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Assignment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject delivery to ${dispatch['customerName']}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final db = await DatabaseHelper().database;
      await db.update('dispatches', {
        'assignmentStatus': 'REJECTED',
        'rejectedAt': DateTime.now().toIso8601String(),
        'rejectionReason': reasonController.text,
        'driverId': null, // Unassign driver so admin can reassign
      }, where: 'id = ?', whereArgs: [dispatch['id']]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment rejected'), backgroundColor: Colors.orange),
      );
      _loadAssignments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Assignments'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAssignments),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
                      const SizedBox(height: 16),
                      const Text('No pending assignments', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const Text('Check back later for new deliveries', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAssignments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _assignments.length,
                    itemBuilder: (ctx, i) => _buildAssignmentCard(_assignments[i]),
                  ),
                ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> a) {
    final date = a['date'] ?? '';
    final time = a['time'] ?? '';
    final isToday = date == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isTomorrow = date == DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
    
    String dateLabel = date;
    if (isToday) dateLabel = 'Today';
    else if (isTomorrow) dateLabel = 'Tomorrow';
    else {
      try {
        dateLabel = DateFormat('EEE, MMM d').format(DateTime.parse(date));
      } catch (_) {}
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with date badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isToday ? Colors.orange.shade50 : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isToday ? Colors.orange : Colors.indigo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(dateLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Chip(
                  label: Text('${a['dishCount'] ?? 0} dishes'),
                  backgroundColor: Colors.grey.shade100,
                  labelStyle: const TextStyle(fontSize: 11),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          
          // Main content
          InkWell(
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => DriverDispatchDetailScreen(dispatch: a)),
            ).then((_) => _loadAssignments()),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['customerName'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(child: Text(a['location'] ?? 'N/A', style: TextStyle(color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('${a['totalPax'] ?? 0} Pax', style: TextStyle(color: Colors.grey.shade600)),
                      if (a['vehicleNo'] != null) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.local_shipping, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(a['vehicleNo'], style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectAssignment(a),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptAssignment(a),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
