// MODULE: MY ATTENDANCE
// Features: Staff Self-Service Punch In/Out, GPS Verify, Geo-fence Check, Calendar History
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../services/geo_fence_service.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '3.3.1_staff_detail_screen.dart';
import 'staff/my_salary_slips_screen.dart';

class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isPunching = false;
  
  // User/Staff info
  Map<String, dynamic>? _staffRecord;
  Map<String, dynamic>? _todayAttendance;
  String? _userMobile;
  String? _firmId;
  
  // Geo-fence
  double? _kitchenLat;
  double? _kitchenLng;
  int _geoFenceRadius = 100;
  bool? _isWithinGeoFence;
  String? _locationMessage;
  
  // Calendar
  DateTime _currentMonth = DateTime.now();
  Map<String, Map<String, dynamic>> _attendanceByDate = {};

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
    _userMobile = sp.getString('last_mobile');
    _firmId = sp.getString('last_firm');
    
    if (_userMobile == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    final db = DatabaseHelper();
    
    // Find staff record by mobile
    final staffList = await db.database.then((d) => d.query(
      'staff',
      where: 'mobile = ? AND isActive = 1',
      whereArgs: [_userMobile],
    ));
    
    if (staffList.isNotEmpty) {
      _staffRecord = staffList.first;
      
      // Load today's attendance
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final attendance = await db.database.then((d) => d.query(
        'attendance',
        where: 'staffId = ? AND date = ?',
        whereArgs: [_staffRecord!['id'], today],
      ));
      
      if (attendance.isNotEmpty) {
        _todayAttendance = attendance.first;
      }
      
      // Load calendar data
      await _loadCalendarData();
    }
    
    // Load firm GPS settings
    if (_firmId != null) {
      final firm = await db.getFirmDetails(_firmId!);
      if (firm != null) {
        _kitchenLat = firm['kitchenLatitude'] as double?;
        _kitchenLng = firm['kitchenLongitude'] as double?;
        _geoFenceRadius = (firm['geoFenceRadius'] as int?) ?? 100;
      }
    }
    
    // Check current location status
    await _checkLocation();
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadCalendarData() async {
    if (_staffRecord == null) return;
    
    final db = await DatabaseHelper().database;
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    final startStr = DateFormat('yyyy-MM-dd').format(firstDay);
    final endStr = DateFormat('yyyy-MM-dd').format(lastDay);
    
    final records = await db.query(
      'attendance',
      where: 'staffId = ? AND date >= ? AND date <= ?',
      whereArgs: [_staffRecord!['id'], startStr, endStr],
      orderBy: 'date ASC',
    );
    
    final Map<String, Map<String, dynamic>> byDate = {};
    for (var record in records) {
      final dateStr = record['date'] as String;
      byDate[dateStr] = record;
    }
    
    setState(() => _attendanceByDate = byDate);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadCalendarData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadCalendarData();
  }

  Future<void> _checkLocation() async {
    if (_kitchenLat == null || _kitchenLng == null) {
      _locationMessage = '⚠️ Kitchen location not configured';
      return;
    }
    
    final geoService = GeoFenceService.instance;
    final status = await geoService.checkLocationStatus();
    
    if (status != LocationStatus.ready) {
      _locationMessage = geoService.getStatusMessage(status);
      _isWithinGeoFence = null;
      return;
    }
    
    final position = await geoService.getCurrentPosition();
    if (position == null) {
      _locationMessage = '❌ Could not get current location';
      _isWithinGeoFence = null;
      return;
    }
    
    _isWithinGeoFence = geoService.isWithinGeoFence(
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
    
    if (_isWithinGeoFence == true) {
      _locationMessage = '✅ You are within the kitchen area (${geoService.formatDistance(distance)})';
    } else {
      _locationMessage = '⚠️ You are ${geoService.formatDistance(distance)} away from kitchen. Punch will be marked as "Outside Location".';
    }
  }

  bool get _hasPunchedIn => _todayAttendance != null;
  bool get _hasPunchedOut => _todayAttendance?['punchOutTime'] != null;

  Future<void> _punchIn() async {
    if (_staffRecord == null || _hasPunchedIn) return;
    
    setState(() => _isPunching = true);
    
    final geoService = GeoFenceService.instance;
    final position = await geoService.getCurrentPosition();
    
    bool isWithinGeoFence = false;
    String locationNote = '';
    
    if (position != null) {
      locationNote = 'GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      
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
    }
    
    final now = DateTime.now();
    await DatabaseHelper().insertAttendance({
      'staffId': _staffRecord!['id'],
      'date': DateFormat('yyyy-MM-dd').format(now),
      'punchInTime': DateFormat('HH:mm').format(now),
      'punchInLat': position?.latitude,
      'punchInLng': position?.longitude,
      'isWithinGeoFence': isWithinGeoFence ? 1 : 0,
      'location': locationNote,
      'status': 'Present',
      'createdAt': now.toIso8601String(),
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isWithinGeoFence 
              ? AppLocalizations.of(context)!.punchSuccess 
              : AppLocalizations.of(context)!.punchWarning),
          backgroundColor: isWithinGeoFence ? Colors.green : Colors.orange,
        ),
      );
    }
    
    await _loadData();
  }

  Future<void> _punchOut() async {
    if (_todayAttendance == null || _hasPunchedOut) return;
    
    setState(() => _isPunching = true);
    
    final geoService = GeoFenceService.instance;
    final position = await geoService.getCurrentPosition();
    
    // Calculate hours worked
    final punchInTime = _todayAttendance!['punchInTime'] as String;
    final punchInParts = punchInTime.split(':');
    final punchInDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      int.parse(punchInParts[0]),
      int.parse(punchInParts[1]),
    );
    
    final now = DateTime.now();
    final hoursWorked = now.difference(punchInDateTime).inMinutes / 60.0;
    final overtime = hoursWorked > 8 ? hoursWorked - 8 : 0.0;
    
    final db = await DatabaseHelper().database;
    await db.update(
      'attendance',
      {
        'punchOutTime': DateFormat('HH:mm').format(now),
        'punchOutLat': position?.latitude,
        'punchOutLng': position?.longitude,
        'hoursWorked': hoursWorked,
        'overtime': overtime,
      },
      where: 'id = ?',
      whereArgs: [_todayAttendance!['id']],
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.punchOutSuccess(hoursWorked.toStringAsFixed(1))),
          backgroundColor: Colors.blue,
        ),
      );
    }
    
    await _loadData();
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.attendanceTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_staffRecord == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.attendanceTitle)),
        body: _buildNoStaffRecord(),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.attendanceTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Salary Slips',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MySalarySlipsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: AppLocalizations.of(context)!.profile,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffDetailScreen(staffId: _staffRecord!['id']),
                ),
              );
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
            Tab(text: AppLocalizations.of(context)!.today, icon: const Icon(Icons.today, size: 18)),
            Tab(text: AppLocalizations.of(context)!.history, icon: const Icon(Icons.calendar_month, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildCalendarTab(),
        ],
      ),
    );
  }

  Widget _buildNoStaffRecord() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noStaffRecord,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.mobileNotLinked,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Text('Mobile: $_userMobile', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTab() {
    final name = _staffRecord!['name'] ?? 'Staff';
    final role = _staffRecord!['role'] ?? '';
    final today = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Staff Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue,
                    child: Text(name[0].toUpperCase(), 
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        if (role.isNotEmpty) Text(role, style: TextStyle(color: Colors.grey.shade600)),
                        Text(today, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Location Status Card
          Card(
            color: _isWithinGeoFence == true 
                ? Colors.green.shade50 
                : _isWithinGeoFence == false 
                    ? Colors.orange.shade50 
                    : Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _isWithinGeoFence == true 
                        ? Icons.location_on 
                        : _isWithinGeoFence == false 
                            ? Icons.location_off 
                            : Icons.location_searching,
                    color: _isWithinGeoFence == true 
                        ? Colors.green 
                        : _isWithinGeoFence == false 
                            ? Colors.orange 
                            : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _locationMessage ?? AppLocalizations.of(context)!.checkingLocation,
                      style: TextStyle(
                        color: _isWithinGeoFence == true 
                            ? Colors.green.shade700 
                            : _isWithinGeoFence == false 
                                ? Colors.orange.shade700 
                                : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await _checkLocation();
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Punch Status & Button
          _buildPunchSection(),
          
          const SizedBox(height: 24),
          
          // Today's Details
          if (_todayAttendance != null) _buildTodayDetails(),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    final monthName = DateFormat('MMMM yyyy').format(_currentMonth);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    
    // Calculate stats
    int totalPresent = _attendanceByDate.length;
    double totalHours = _attendanceByDate.values.fold(0, (sum, a) => sum + ((a['hoursWorked'] as num?)?.toDouble() ?? 0));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Stats Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(AppLocalizations.of(context)!.present, '$totalPresent', Icons.check_circle, Colors.green),
                _buildStatCard(AppLocalizations.of(context)!.totalHours, totalHours.toStringAsFixed(1), Icons.access_time, Colors.blue),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Month Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousMonth,
              ),
              Text(
                monthName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Weekday Headers
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: d == 'S' ? Colors.grey.shade700 : Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          
          // Calendar Grid
          _buildCalendarGrid(daysInMonth, firstWeekday),
          
          const SizedBox(height: 16),
          
          // Legend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(Colors.green, 'Present'),
                _buildLegendItem(Colors.red, 'Absent'),
                _buildLegendItem(Colors.purple, 'Holiday'),
                _buildLegendItem(Colors.amber, 'Missing'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(int daysInMonth, int firstWeekday) {
    final offset = firstWeekday - 1;
    final totalCells = offset + daysInMonth;
    final rows = (totalCells / 7).ceil();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.85,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayNum = index - offset + 1;
        
        if (dayNum < 1 || dayNum > daysInMonth) {
          return Container();
        }
        
        return _buildDayCell(dayNum);
      },
    );
  }

  Widget _buildDayCell(int day) {
    final dateStr = DateFormat('yyyy-MM-dd').format(
      DateTime(_currentMonth.year, _currentMonth.month, day),
    );
    final attendance = _attendanceByDate[dateStr];
    final isToday = DateTime.now().year == _currentMonth.year &&
        DateTime.now().month == _currentMonth.month &&
        DateTime.now().day == day;
    final isFuture = DateTime(_currentMonth.year, _currentMonth.month, day).isAfter(DateTime.now());
    final isSunday = DateTime(_currentMonth.year, _currentMonth.month, day).weekday == 7;
    
    final isPresent = attendance != null;
    final punchIn = attendance?['punchInTime']?.toString();
    final punchOut = attendance?['punchOutTime']?.toString();
    final hoursWorked = (attendance?['hoursWorked'] as num?)?.toDouble() ?? 0;
    
    // Check if punch is missing (present but no punch in or no punch out)
    final hasMissingPunch = isPresent && (punchIn == null || punchOut == null);
    
    Color bandColor;
    if (isFuture) {
      bandColor = Colors.grey.shade300;
    } else if (isSunday && !isPresent) {
      bandColor = Colors.purple;
    } else if (isPresent && hasMissingPunch) {
      bandColor = Colors.amber;
    } else if (isPresent) {
      bandColor = Colors.green;
    } else {
      bandColor = Colors.red;
    }
    
    return GestureDetector(
      onTap: isFuture ? null : () => _showDayDetails(day, attendance, isSunday),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isToday ? Colors.blue : Colors.grey.shade300,
            width: isToday ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Color band at top with date
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              color: bandColor,
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isFuture ? Colors.grey : Colors.white,
                  ),
                ),
              ),
            ),
            // Content area - punch times
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!isFuture && isPresent) ...[
                      Text(
                        punchIn ?? '-',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        punchOut ?? '-',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hoursWorked > 0)
                        Text(
                          '${hoursWorked.toStringAsFixed(1)}h',
                          style: TextStyle(
                            fontSize: 7,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ] else if (!isFuture && !isPresent && isSunday) ...[
                      Text(
                        'Off',
                        style: TextStyle(fontSize: 8, color: Colors.purple.shade300),
                      ),
                    ] else if (!isFuture && !isPresent) ...[
                      Icon(Icons.remove, size: 10, color: Colors.grey.shade400),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPunchSection() {
    if (!_hasPunchedIn) {
      return Column(
        children: [
          Icon(Icons.login, size: 60, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.readyToPunchIn, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _isPunching ? null : _punchIn,
              icon: _isPunching 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login, size: 28),
              label: Text(_isPunching ? AppLocalizations.of(context)!.punching : AppLocalizations.of(context)!.punchIn, 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    } else if (!_hasPunchedOut) {
      final punchInTime = _todayAttendance!['punchInTime'] ?? '--:--';
      return Column(
        children: [
          Icon(Icons.timer, size: 60, color: Colors.blue.shade300),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.workingSince(punchInTime), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildElapsedTime(),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _isPunching ? null : _punchOut,
              icon: _isPunching 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.logout, size: 28),
              label: Text(_isPunching ? AppLocalizations.of(context)!.punching : AppLocalizations.of(context)!.punchOut, 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    } else {
      final punchInTime = _todayAttendance!['punchInTime'] ?? '--:--';
      final punchOutTime = _todayAttendance!['punchOutTime'] ?? '--:--';
      final hoursWorked = (_todayAttendance!['hoursWorked'] as num?)?.toDouble() ?? 0;
      final overtime = (_todayAttendance!['overtime'] as num?)?.toDouble() ?? 0;
      
      return Column(
        children: [
          Icon(Icons.check_circle, size: 60, color: Colors.green.shade400),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.todayShiftCompleted, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('$punchInTime → $punchOutTime', style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Chip(
                avatar: const Icon(Icons.access_time, size: 18),
                label: Text('${hoursWorked.toStringAsFixed(1)} hours'),
                backgroundColor: Colors.blue.shade50,
              ),
              if (overtime > 0) ...[
                const SizedBox(width: 8),
                Chip(
                  avatar: const Icon(Icons.more_time, size: 18),
                  label: Text('+${overtime.toStringAsFixed(1)} OT'),
                  backgroundColor: Colors.orange.shade50,
                ),
              ],
            ],
          ),
        ],
      );
    }
  }

  Widget _buildElapsedTime() {
    final punchInTime = _todayAttendance!['punchInTime'] as String;
    final punchInParts = punchInTime.split(':');
    final punchInDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      int.parse(punchInParts[0]),
      int.parse(punchInParts[1]),
    );
    
    final elapsed = DateTime.now().difference(punchInDateTime);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    
    return Text(
      AppLocalizations.of(context)!.elapsedTime(hours, minutes),
      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
    );
  }

  Widget _buildTodayDetails() {
    final punchInTime = _todayAttendance!['punchInTime'] ?? '--:--';
    final punchOutTime = _todayAttendance!['punchOutTime'];
    final isWithinGeoFence = _todayAttendance!['isWithinGeoFence'] == 1;
    final location = _todayAttendance!['location'] ?? '';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.todayDetails, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            _detailRow(AppLocalizations.of(context)!.punchedIn, punchInTime, Icons.login, Colors.green),
            if (punchOutTime != null)
              _detailRow(AppLocalizations.of(context)!.punchedOut, punchOutTime, Icons.logout, Colors.red),
            _detailRow(
              AppLocalizations.of(context)!.location, 
              isWithinGeoFence ? AppLocalizations.of(context)!.withinKitchen : AppLocalizations.of(context)!.outsideKitchen, 
              isWithinGeoFence ? Icons.location_on : Icons.location_off,
              isWithinGeoFence ? Colors.green : Colors.orange,
            ),
            if (location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(location, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
  void _showDayDetails(int day, Map<String, dynamic>? attendance, bool isSunday) {
    var dateStr = DateFormat('d MMM yyyy').format(
      DateTime(_currentMonth.year, _currentMonth.month, day),
    );
    
    String status;
    Color statusColor;
    final punchIn = attendance?['punchInTime']?.toString();
    final punchOut = attendance?['punchOutTime']?.toString();
    final hoursWorked = (attendance?['hoursWorked'] as num?)?.toDouble() ?? 0;
    
    if (attendance == null && isSunday) {
      status = 'Holiday';
      statusColor = Colors.purple;
    } else if (attendance == null) {
      status = 'Absent';
      statusColor = Colors.red;
    } else if (punchIn == null || punchOut == null) {
      status = 'Missing Punch';
      statusColor = Colors.amber;
    } else {
      status = 'Present';
      statusColor = Colors.green;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dateStr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
              ],
            ),
            if (attendance != null) ...[
              const SizedBox(height: 16),
              _buildDetailRow('Punch In:', punchIn ?? '-'),
              const SizedBox(height: 8),
              _buildDetailRow('Punch Out:', punchOut ?? '-'),
              const SizedBox(height: 8),
              _buildDetailRow('Total Hours:', '${hoursWorked.toStringAsFixed(1)} hrs'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
