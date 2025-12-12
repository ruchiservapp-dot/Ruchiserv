// MODULE: STAFF MANAGEMENT (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-08 | Features: Tabbed Layout, GPS Attendance, Staff Types, Punch In/Out
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../services/geo_fence_service.dart';
import '3.3.1_staff_detail_screen.dart';
import '3.3.2_staff_payroll_screen.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _todayAttendance = [];
  bool _isLoading = true;
  String? _firmId;
  
  // Kitchen GPS (for geo-fence check)
  double? _kitchenLat;
  double? _kitchenLng;
  int _geoFenceRadius = 100;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final sp = await SharedPreferences.getInstance();
    _firmId = sp.getString('last_firm');
    
    // Load firm GPS settings
    if (_firmId != null) {
      final firm = await DatabaseHelper().getFirmDetails(_firmId!);
      if (firm != null) {
        _kitchenLat = firm['kitchenLatitude'] as double?;
        _kitchenLng = firm['kitchenLongitude'] as double?;
        _geoFenceRadius = (firm['geoFenceRadius'] as int?) ?? 100;
      }
    }
    
    // Load staff
    final staff = await DatabaseHelper().getAllStaff();
    
    // Load today's attendance
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final db = await DatabaseHelper().database;
    final attendance = await db.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [today],
    );
    
    setState(() {
      _staffList = staff;
      _todayAttendance = attendance;
      _isLoading = false;
    });
  }

  bool _hasAttendanceToday(int staffId) {
    return _todayAttendance.any((a) => a['staffId'] == staffId);
  }

  Map<String, dynamic>? _getAttendanceRecord(int staffId) {
    try {
      return _todayAttendance.firstWhere((a) => a['staffId'] == staffId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _punchIn(int staffId) async {
    if (_hasAttendanceToday(staffId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.alreadyPunchedIn)),
      );
      return;
    }

    // Get current location
    final geoService = GeoFenceService.instance;
    final status = await geoService.checkLocationStatus();
    
    if (status != LocationStatus.ready) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(geoService.getStatusMessage(status))),
        );
      }
      return;
    }

    final position = await geoService.getCurrentPosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.couldNotGetLocation)),
        );
      }
      return;
    }

    // Check geo-fence
    bool isWithinGeoFence = false;
    String locationNote = 'GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    
    if (_kitchenLat != null && _kitchenLng != null) {
      isWithinGeoFence = geoService.isWithinGeoFence(
        staffLat: position.latitude,
        staffLng: position.longitude,
        kitchenLat: _kitchenLat!,
        kitchenLng: _kitchenLng!,
        radiusMeters: _geoFenceRadius.toDouble(),
      );
      
      final distance = geoService.calculateDistance(
        lat1: position.latitude,
        lng1: position.longitude,
        lat2: _kitchenLat!,
        lng2: _kitchenLng!,
      );
      locationNote += ' | ${geoService.formatDistance(distance)} from kitchen';
    }

    final now = DateTime.now();
    await DatabaseHelper().insertAttendance({
      'staffId': staffId,
      'date': DateFormat('yyyy-MM-dd').format(now),
      'punchInTime': DateFormat('HH:mm').format(now),
      'punchInLat': position.latitude,
      'punchInLng': position.longitude,
      'isWithinGeoFence': isWithinGeoFence ? 1 : 0,
      'location': locationNote,
      'status': 'Present',
      'createdAt': now.toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isWithinGeoFence 
              ? AppLocalizations.of(context)!.punchedInGeo 
              : AppLocalizations.of(context)!.punchedInNoGeo),
          backgroundColor: isWithinGeoFence ? Colors.green : Colors.orange,
        ),
      );
    }
    
    _loadData();
  }

  Future<void> _punchOut(int staffId, int attendanceId) async {
    final geoService = GeoFenceService.instance;
    final position = await geoService.getCurrentPosition();
    
    // Calculate hours worked
    final attendance = _getAttendanceRecord(staffId);
    double hoursWorked = 0;
    double overtime = 0;
    
    if (attendance != null && attendance['punchInTime'] != null) {
      final punchInTime = attendance['punchInTime'] as String;
      final punchInParts = punchInTime.split(':');
      final punchInDateTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        int.parse(punchInParts[0]),
        int.parse(punchInParts[1]),
      );
      
      final now = DateTime.now();
      hoursWorked = now.difference(punchInDateTime).inMinutes / 60.0;
      
      // Calculate overtime (anything over 8 hours)
      if (hoursWorked > 8) {
        overtime = hoursWorked - 8;
      }
    }

    final db = await DatabaseHelper().database;
    await db.update(
      'attendance',
      {
        'punchOutTime': DateFormat('HH:mm').format(DateTime.now()),
        'punchOutLat': position?.latitude,
        'punchOutLng': position?.longitude,
        'hoursWorked': hoursWorked,
        'overtime': overtime,
      },
      where: 'id = ?',
      whereArgs: [attendanceId],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.punchedOutMsg(hoursWorked.toStringAsFixed(1), overtime > 0 ? ' (${overtime.toStringAsFixed(1)} ${AppLocalizations.of(context)!.otLabel})' : '')),
          backgroundColor: Colors.blue,
        ),
      );
    }
    
    _loadData();
  }

  Future<void> _addStaff() async {
    final result = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const StaffDetailScreen()),
    );
    if (result == true) _loadData();
  }

  Color _getStaffTypeColor(String? type) {
    switch (type) {
      case 'PERMANENT': return Colors.green;
      case 'DAILY_WAGE': return Colors.orange;
      case 'CONTRACTOR': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.staffManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments),
            tooltip: AppLocalizations.of(context)!.payroll,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const StaffPayrollScreen(),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.staff),
            Tab(text: AppLocalizations.of(context)!.today),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addStaff,
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStaffTab(),
                _buildTodayAttendanceTab(),
              ],
            ),
    );
  }

  Widget _buildStaffTab() {
    if (_staffList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noStaffMembers, style: const TextStyle(color: Colors.grey)),
            Text(AppLocalizations.of(context)!.tapToAddStaff, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _staffList.length,
      itemBuilder: (context, index) {
        final staff = _staffList[index];
        final hasAttendance = _hasAttendanceToday(staff['id']);
        final attendance = _getAttendanceRecord(staff['id']);
        final hasPunchedOut = attendance?['punchOutTime'] != null;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: _getStaffTypeColor(staff['staffType']),
                  child: Text(
                    (staff['name'] ?? 'S')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                if (hasAttendance)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: hasPunchedOut ? Colors.blue : Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(staff['name'] ?? AppLocalizations.of(context)!.unknown),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${staff['role'] ?? AppLocalizations.of(context)!.staff} | ${staff['mobile'] ?? AppLocalizations.of(context)!.noMobile}"),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStaffTypeColor(staff['staffType']).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        staff['staffType'] == 'DAILY_WAGE' ? AppLocalizations.of(context)!.dailyWage : (staff['staffType'] == 'CONTRACTOR' ? AppLocalizations.of(context)!.contractor : AppLocalizations.of(context)!.permanent),
                        style: TextStyle(
                          fontSize: 10,
                          color: _getStaffTypeColor(staff['staffType']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (hasAttendance && !hasPunchedOut)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'IN: ${attendance?['punchInTime'] ?? ''}',
                          style: const TextStyle(fontSize: 10, color: Colors.green),
                        ),
                      ),
                    if (hasPunchedOut)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${attendance?['hoursWorked']?.toStringAsFixed(1) ?? '0'}h',
                          style: const TextStyle(fontSize: 10, color: Colors.blue),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hasAttendance)
                  IconButton(
                    icon: const Icon(Icons.login, color: Colors.green),
                    onPressed: () => _punchIn(staff['id']),
                    tooltip: "Punch In",
                  )
                else if (!hasPunchedOut)
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.orange),
                    onPressed: () => _punchOut(staff['id'], attendance!['id']),
                    tooltip: "Punch Out",
                  )
                else
                  const Icon(Icons.check_circle, color: Colors.blue),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () async {
                    final result = await Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => StaffDetailScreen(staffId: staff['id']),
                      ),
                    );
                    if (result == true) _loadData();
                  },
                ),
              ],
            ),
            onTap: () async {
              final result = await Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => StaffDetailScreen(staffId: staff['id']),
                ),
              );
              if (result == true) _loadData();
            },
          ),
        );
      },
    );
  }

  Widget _buildTodayAttendanceTab() {
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());
    
    return Column(
      children: [
        // Summary Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(AppLocalizations.of(context)!.totalStaff, _staffList.length.toString(), Icons.people),
              _buildStatCard(AppLocalizations.of(context)!.present, _todayAttendance.length.toString(), Icons.check_circle, Colors.green),
              _buildStatCard(AppLocalizations.of(context)!.absent, (_staffList.length - _todayAttendance.length).toString(), Icons.cancel, Colors.red),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(today, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        
        // Attendance List
        Expanded(
          child: _todayAttendance.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noAttendanceToday))
              : ListView.builder(
                  itemCount: _todayAttendance.length,
                  itemBuilder: (context, index) {
                    final record = _todayAttendance[index];
                    final staff = _staffList.firstWhere(
                      (s) => s['id'] == record['staffId'],
                      orElse: () => {'name': AppLocalizations.of(context)!.unknown},
                    );
                    final isWithinGeoFence = record['isWithinGeoFence'] == 1;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isWithinGeoFence ? Colors.green : Colors.orange,
                          child: Icon(
                            isWithinGeoFence ? Icons.location_on : Icons.location_off,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(staff['name'] ?? AppLocalizations.of(context)!.unknown),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('In: ${record['punchInTime'] ?? '-'}'
                                '${record['punchOutTime'] != null ? ' | Out: ${record['punchOutTime']}' : ' (${AppLocalizations.of(context)!.workingStatus})'}'),
                            if (record['hoursWorked'] != null && record['hoursWorked'] > 0)
                              Text(
                                '${(record['hoursWorked'] as num).toStringAsFixed(1)} hrs'
                                '${(record['overtime'] ?? 0) > 0 ? ' (${(record['overtime'] as num).toStringAsFixed(1)} ${AppLocalizations.of(context)!.otLabel})' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: isWithinGeoFence
                            ? const Icon(Icons.verified, color: Colors.green)
                            : const Icon(Icons.warning, color: Colors.orange),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.grey, size: 28),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
