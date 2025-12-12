// MODULE: MY ATTENDANCE (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-08 | Features: Staff Self-Service Punch In/Out, GPS Verify, Geo-fence Check
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../services/geo_fence_service.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _checkLocation() async {
    if (_kitchenLat == null || _kitchenLng == null) {
      _locationMessage = '⚠️ Kitchen location not configured'; // Not critical to translate debug strings
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

  String _getLocationMessage(BuildContext context) {
      if (_locationMessage != null) return _locationMessage!;
      return AppLocalizations.of(context)!.checkingLocation;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.attendanceTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _staffRecord == null
              ? _buildNoStaffRecord()
              : _buildAttendanceView(),
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

  Widget _buildAttendanceView() {
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

  Widget _buildPunchSection() {
    if (!_hasPunchedIn) {
      // Not yet punched in
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
      // Punched in, not yet out
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
      // Already completed
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
}
