// MODULE: ORDER MANAGEMENT (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// lib/screens/2.0_orders_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

import '../db/database_helper.dart';
import '2.2_orders_list_screen.dart';
// If/when you want AWS back, uncomment the next line and set useAws = true below
// import '../db/aws/aws_api.dart';

class OrderCalendarScreen extends StatefulWidget {
  const OrderCalendarScreen({super.key});

  @override
  State<OrderCalendarScreen> createState() => _OrderCalendarScreenState();
}

class _OrderCalendarScreenState extends State<OrderCalendarScreen> with RouteAware {
  // ---- Config you can tweak later (or move to Settings) ----
  static const double _utilizationAmberAt = 0.50; // >=50% = amber (User request: Green < 50%)
  static const double _utilizationRedAt = 0.90;   // >=90% = red (User request: Red >= 90%)
  int _dailyCapacity = 500;                       // Dynamic from DB
  static const bool useAws = false;               // keep false to avoid previous shape errors

  final DateTime _today = DateTime.now();

  late DateTime _firstDayLimit;
  late DateTime _lastDayLimit;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  CalendarFormat _calendarFormat = CalendarFormat.month;

  // pax map keyed by 'yyyy-MM-dd'
  final Map<String, int> _dailyPax = {};

  // month stats
  int _monthTotalPax = 0;
  double _monthUtilization = 0.0;

  bool _isMonthLoading = false;
  bool _showOfflineChip = false;

  @override
  void initState() {
    super.initState();
    // back 3 months, forward 12 months from "today"
    final back3 = DateTime(_today.year, _today.month - 3, 1);
    final fwd12 = DateTime(_today.year, _today.month + 12, 1);
    _firstDayLimit = DateTime(back3.year, back3.month, 1);
    _lastDayLimit = DateTime(fwd12.year, fwd12.month + 1, 0); // end of month

    _selectedDay = DateTime(_today.year, _today.month, _today.day);
    _focusedDay = DateTime(_today.year, _today.month, 1);

    // initial load for current month
    _loadFirmCapacity();
    _loadCalendarForMonth(_focusedDay);
  }

  Future<void> _loadFirmCapacity() async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm');
    if (firmId != null) {
      final firm = await DatabaseHelper().getFirmDetails(firmId);
      if (firm != null && mounted) {
        setState(() {
          _dailyCapacity = (firm['capacity'] as int?) ?? 500;
          // Refresh calendar to update colors
        });
      }
    }
  }

  // ---------- Helpers ----------
  String _keyOf(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  void _jumpToToday() {
    _selectedDay = DateTime(_today.year, _today.month, _today.day);
    _focusedDay = DateTime(_today.year, _today.month, 1);
    setState(() {});
  }

  // ---------- System calendar ----------
  Future<void> _openSystemCalendar() async {
    // Try platform schemes; fall back to Google Calendar
    final candidates = <Uri>[
      // iOS/macOS
      Uri.parse('calshow://'),
      // Android content deep link (may not work on all devices)
      Uri.parse('content://com.android.calendar/time'),
      // Fallback
      Uri.parse('https://calendar.google.com'),
    ];

    for (final uri in candidates) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // As a last resort try opening google calendar in browser
    await launchUrl(Uri.parse('https://calendar.google.com'), mode: LaunchMode.externalApplication);
  }

  // ---------- Data load (Local DB primary, safe parsing) ----------
  Future<void> _loadCalendarForMonth(DateTime monthAnchor) async {
    setState(() {
      _isMonthLoading = true;
      _showOfflineChip = false;
    });

    // compute month range
    final monthStart = DateTime(monthAnchor.year, monthAnchor.month, 1);
    final monthEnd = DateTime(monthAnchor.year, monthAnchor.month + 1, 0);

    final Map<String, int> fresh = {};

    try {
      // 1) Local DB (reliable)
      final all = await DatabaseHelper().getAllOrdersWithPax();
      for (final row in all) {
        final dateStr = (row['date'] ?? '').toString();
        if (dateStr.isEmpty) continue;
        DateTime? d;
        try {
          d = DateTime.parse(dateStr);
        } catch (_) {
          continue;
        }
        if (d.isBefore(monthStart) || d.isAfter(monthEnd)) continue;

        final paxAny = row['totalPax'] ?? row['pax'] ?? 0;
        final pax = paxAny is int
            ? paxAny
            : (paxAny is num ? paxAny.toInt() : int.tryParse(paxAny.toString()) ?? 0);

        final k = _keyOf(d);
        fresh[k] = (fresh[k] ?? 0) + pax;
      }

      // 2) (Optional) AWS overlay if you later enable it.
      // keeping the robust normalizer to avoid the earlier type errors.
      if (useAws) {
        // final result = await AwsApi.callDbHandler(
        //   method: 'GET',
        //   table: 'orders',
        //   // pass a month window if your API supports, else full table
        //   // filters: {'month': DateFormat('yyyy-MM').format(monthAnchor)},
        // );
        final result = null; // placeholder to keep analyzer happy

        List<dynamic> dataList = const [];
        if (result is List) {
          dataList = result;
        } else if (result is Map && result['data'] is List) {
          dataList = result['data'] as List;
        }

        for (final item in dataList) {
          if (item is! Map) continue;
          final dateStr = (item['date'] ?? item['order_date'] ?? '').toString().trim();
          if (dateStr.isEmpty) continue;
          DateTime? d;
          try {
            d = DateTime.parse(dateStr);
          } catch (_) {
            continue;
          }
          if (d.isBefore(monthStart) || d.isAfter(monthEnd)) continue;

          final paxAny = item['totalPax'] ?? item['pax'] ?? 0;
          final pax = paxAny is int
              ? paxAny
              : (paxAny is num ? paxAny.toInt() : int.tryParse(paxAny.toString()) ?? 0);

          final k = _keyOf(d);
          fresh[k] = (fresh[k] ?? 0) + pax;
        }
      }

      // Compute month stats
      int total = 0;
      for (int day = 1; day <= monthEnd.day; day++) {
        final d = DateTime(monthStart.year, monthStart.month, day);
        total += fresh[_keyOf(d)] ?? 0;
      }
      final daysInMonth = monthEnd.day;
      final capacityMonth = daysInMonth * _dailyCapacity;
      final util = capacityMonth == 0 ? 0.0 : (total / capacityMonth);

      setState(() {
        _dailyPax
          ..clear()
          ..addAll(fresh);
        _monthTotalPax = total;
        _monthUtilization = util.clamp(0.0, 1.0);
      });
    } catch (_) {
      setState(() {
        _showOfflineChip = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isMonthLoading = false);
      }
    }
  }

  // ---------- Navigation handlers ----------
  Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    setState(() {
      _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      _focusedDay = focusedDay;
    });

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrdersListScreen(date: _selectedDay!)),
    );

    // On return: always jump back to TODAY and reload this month
    if (mounted) {
      _jumpToToday();
      _loadCalendarForMonth(_focusedDay);
    }
  }

  void _onMonthChanged(DateTime newFocused) {
    setState(() {
      _focusedDay = DateTime(newFocused.year, newFocused.month, 1);
    });
    _loadCalendarForMonth(_focusedDay);
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    // Dynamic row height optimized for visibility
    // Prevent giant cells on wide screens (laptops/tablets) by clamping height
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth - 32;
    final double rawSquareHeight = (cardWidth / 7);
    
    // Clamp height: Min 65 (for text visibility), Max 85 (to fit screen on laptops)
    final double cellHeight = rawSquareHeight.clamp(65.0, 95.0);

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for contrast
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.ordersCalendarTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: Colors.indigo),
            tooltip: AppLocalizations.of(context)!.openSystemCalendar,
            onPressed: _openSystemCalendar,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isMonthLoading)
            const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
            
          Expanded(
            child: ListView( // Scrollable to handle smaller screens or tall calendars
              padding: const EdgeInsets.all(16.0),
              children: [
                // Calendar Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TableCalendar(
                    firstDay: _firstDayLimit,
                    lastDay: _lastDayLimit,
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    rowHeight: cellHeight, // responsive height
                    daysOfWeekHeight: 40,
                    availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                    
                    // Style Header
                    headerVisible: true, 
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      leftChevronIcon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_left, color: Colors.black54),
                      ),
                      rightChevronIcon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_right, color: Colors.black54),
                      ),
                      headerPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    
                    // Style Days of Week
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
                      weekendStyle: TextStyle(color: Colors.red[300], fontWeight: FontWeight.bold, fontSize: 12),
                    ),

                    selectedDayPredicate: (day) =>
                        _selectedDay != null && isSameDay(_selectedDay, day),

                    onDaySelected: _onDaySelected,
                    onPageChanged: _onMonthChanged,

                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (ctx, day, focused) => _buildDayCell(ctx, day, focused),
                      todayBuilder: (ctx, day, focused) => _buildDayCell(ctx, day, focused),
                      selectedBuilder: (ctx, day, focused) => _buildDayCell(ctx, day, focused),
                      outsideBuilder: (ctx, day, focused) => _buildDayCell(ctx, day, focused),
                    ),

                    calendarStyle: const CalendarStyle(
                      outsideDaysVisible: true,
                      cellMargin: EdgeInsets.zero, // We handle margins/padding in builder
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                // Legend / Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendDot(Colors.green[100]!, AppLocalizations.of(context)!.utilizationLow),
                    const SizedBox(width: 16),
                    _buildLegendDot(Colors.orange[100]!, AppLocalizations.of(context)!.utilizationMed),
                    const SizedBox(width: 16),
                    _buildLegendDot(Colors.red[100]!, AppLocalizations.of(context)!.utilizationHigh),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ---------- Day Cell ----------
  Widget _buildDayCell(BuildContext context, DateTime day, DateTime focusedMonth) {
    final dateKey = _keyOf(day);
    final pax = _dailyPax[dateKey] ?? 0;
    final isOutside = day.month != focusedMonth.month;
    final isToday = isSameDay(day, _today);
    // final isPastDay = _isPast(day); // Optional: dim past days?
    
    // Modern colors
    Color bgColor = Colors.transparent;
    Color textColor = isOutside ? Colors.grey.shade300 : Colors.black87;
    FontWeight fontWeight = FontWeight.normal;
    Border? border;

    if (!isOutside) {
      if (pax > 0) {
        final u = pax / (_dailyCapacity > 0 ? _dailyCapacity : 1);
        if (u >= _utilizationRedAt) {
          bgColor = const Color(0xFFFFEBEE); // Red 50
          textColor = const Color(0xFFC62828); // Red 800
        } else if (u >= _utilizationAmberAt) {
          bgColor = const Color(0xFFFFF3E0); // Orange 50
          textColor = const Color(0xFFEF6C00); // Orange 800
        } else {
          bgColor = const Color(0xFFE8F5E9); // Green 50
          textColor = const Color(0xFF2E7D32); // Green 800
        }
        fontWeight = FontWeight.bold;
      }
      
      if (isToday) {
        border = Border.all(color: Colors.indigo, width: 2);
      } else {
        border = Border.all(color: Colors.grey.shade300, width: 1);
      }
    } else {
        border = Border.all(color: Colors.grey.shade200, width: 1);
    }

    return Container(
      margin: const EdgeInsets.all(4), // Gap between cells
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Stack(
        children: [
          // Date (Top Left)
          Positioned(
            top: 6,
            left: 8,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                color: isOutside ? Colors.grey[300] : (isSameDay(day, _selectedDay) ? Colors.indigo : Colors.grey[600]),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Pax (Center)
          if (!isOutside && pax > 0)
            Center(
              child: Text(
                '$pax',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: fontWeight,
                  color: textColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
