// MODULE: STAFF ATTENDANCE CALENDAR
// Features: Monthly calendar view showing staff punch in/out times per day
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '3.3.1_staff_detail_screen.dart';

class StaffAttendanceCalendarScreen extends StatefulWidget {
  final int staffId;
  final String staffName;
  
  const StaffAttendanceCalendarScreen({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<StaffAttendanceCalendarScreen> createState() => _StaffAttendanceCalendarScreenState();
}

class _StaffAttendanceCalendarScreenState extends State<StaffAttendanceCalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  bool _isLoading = true;
  
  // Attendance data indexed by date string (yyyy-MM-dd)
  Map<String, Map<String, dynamic>> _attendanceByDate = {};
  
  // Stats for the month
  int _totalPresent = 0;
  double _totalHours = 0;
  double _totalOT = 0;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);
    
    final db = await DatabaseHelper().database;
    
    // Get first and last day of current month
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    final startStr = DateFormat('yyyy-MM-dd').format(firstDay);
    final endStr = DateFormat('yyyy-MM-dd').format(lastDay);
    
    // Fetch attendance records for this staff and month
    final records = await db.query(
      'attendance',
      where: 'staffId = ? AND date >= ? AND date <= ?',
      whereArgs: [widget.staffId, startStr, endStr],
      orderBy: 'date ASC',
    );
    
    // Index by date
    final Map<String, Map<String, dynamic>> byDate = {};
    int present = 0;
    double hours = 0;
    double ot = 0;
    
    for (var record in records) {
      final dateStr = record['date'] as String;
      byDate[dateStr] = record;
      present++;
      hours += (record['hoursWorked'] as num?)?.toDouble() ?? 0;
      ot += (record['overtime'] as num?)?.toDouble() ?? 0;
    }
    
    setState(() {
      _attendanceByDate = byDate;
      _totalPresent = present;
      _totalHours = hours;
      _totalOT = ot;
      _isLoading = false;
    });
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadMonthData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadMonthData();
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(_currentMonth);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.staffName),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: AppLocalizations.of(context)!.profile,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffDetailScreen(staffId: widget.staffId),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Month Stats Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(AppLocalizations.of(context)!.present, '$_totalPresent', Icons.check_circle, Colors.green),
                  _buildStatCard(AppLocalizations.of(context)!.totalHours, _totalHours.toStringAsFixed(1), Icons.access_time, Colors.blue),
                  _buildStatCard(AppLocalizations.of(context)!.otLabel, _totalOT.toStringAsFixed(1), Icons.timer, Colors.orange),
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
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCalendarGrid(daysInMonth, firstWeekday),
            
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
      ),
    );
  }

  Widget _buildCalendarGrid(int daysInMonth, int firstWeekday) {
    // firstWeekday: 1=Monday, 7=Sunday
    // We need to offset by (firstWeekday - 1) for Monday-start calendar
    final offset = firstWeekday - 1;
    final totalCells = offset + daysInMonth;
    final rows = (totalCells / 7).ceil();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.85, // Slightly taller cells to show punch times
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayNum = index - offset + 1;
        
        // Empty cell for offset or overflow
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
    
    // Determine status
    final isPresent = attendance != null;
    final punchIn = attendance?['punchInTime']?.toString();
    final punchOut = attendance?['punchOutTime']?.toString();
    final hoursWorked = (attendance?['hoursWorked'] as num?)?.toDouble() ?? 0;
    
    // Check if punch is missing (present but no punch in or no punch out)
    final hasMissingPunch = isPresent && (punchIn == null || punchOut == null);
    
    // Color coding: Green=Present, Red=Absent, Purple=Holiday/Sunday, Amber=Missing punch
    Color bandColor;
    
    if (isFuture) {
      bandColor = Colors.grey.shade300;
    } else if (isSunday && !isPresent) {
      // Holiday/Sunday - Purple
      bandColor = Colors.purple;
    } else if (isPresent && hasMissingPunch) {
      // Missing punch in or out - Amber
      bandColor = Colors.amber;
    } else if (isPresent) {
      // Present - Green
      bandColor = Colors.green;
    } else {
      // Absent - Red
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
                      // Punch In
                      Text(
                        punchIn ?? '-',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Punch Out
                      Text(
                        punchOut ?? '-',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Hours
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

  void _showDayDetails(int day, Map<String, dynamic>? attendance, bool isSunday) {
    final dateStr = DateFormat('d MMM yyyy').format(
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
