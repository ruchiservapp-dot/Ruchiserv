// lib/screens/2.0_orders_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const double _utilizationAmberAt = 0.60; // >=60% = amber
  static const double _utilizationRedAt = 0.85;   // >=85% = red
  static const int _dailyCapacity = 500;          // default kitchen capacity pax/day
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
    _loadCalendarForMonth(_focusedDay);
  }

  // ---------- Helpers ----------
  String _keyOf(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  bool _isPast(DateTime d) {
    final dd = DateTime(d.year, d.month, d.day);
    final tt = DateTime(_today.year, _today.month, _today.day);
    return dd.isBefore(tt);
  }

  void _jumpToToday() {
    _selectedDay = DateTime(_today.year, _today.month, _today.day);
    _focusedDay = DateTime(_today.year, _today.month, 1);
    setState(() {});
  }

  Color _bgFor(int pax) {
    if (pax <= 0) return Colors.transparent;
    final u = pax / _dailyCapacity;
    if (u >= _utilizationRedAt) {
      return Colors.red.withOpacity(0.15);
    } else if (u >= _utilizationAmberAt) {
      return Colors.orange.withOpacity(0.12);
    } else {
      return Colors.green.withOpacity(0.10);
    }
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

  // ---------- Day Cell ----------
  Widget _buildDayCell(BuildContext context, DateTime day, DateTime focusedMonth) {
    final dateKey = _keyOf(day);
    final pax = _dailyPax[dateKey] ?? 0;
    final isOutside = day.month != focusedMonth.month;
    final isToday = isSameDay(day, _today);
    final isPastDay = _isPast(day);

    final base = _bgFor(pax);
    final Color bg = isOutside ? Colors.transparent : base;
    final Color border = isToday
        ? Theme.of(context).colorScheme.primary.withOpacity(0.35)
        : Colors.transparent;

    // Text styles
    final dateStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: isOutside
          ? Colors.grey.shade400
          : (isPastDay ? Colors.grey.shade500 : Colors.grey.shade700),
    );

    final paxStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: isOutside
          ? Colors.grey.shade400
          : (isPastDay ? Colors.grey.shade600 : Colors.grey.shade900),
    );

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: isToday ? 1.3 : 0.8),
      ),
      child: Stack(
        children: [
          // Date (top-left)
          Positioned(
            top: 6,
            left: 8,
            child: Text('${day.day}', style: dateStyle),
          ),
          // Pax (center)
          Center(
            child: Text(
              pax > 0 ? pax.toString() : '',
              style: paxStyle,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ),
          // Past overlay (light grey wash for visual cue, but still tappable)
          if (isPastDay)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withOpacity(0.0), // keep subtle
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
    final monthLabel = DateFormat('MMMM yyyy').format(_focusedDay);
    final pctText = (_monthUtilization * 100).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: Text(monthLabel),
        centerTitle: true,
        actions: [
          // System calendar icon (Option 1)
          IconButton(
            tooltip: 'Open system calendar',
            icon: const Icon(Icons.event),
            onPressed: () async {
              await _openSystemCalendar();
              if (!mounted) return;
              // when back to our app, highlight TODAY again
              _jumpToToday();
              _loadCalendarForMonth(_focusedDay);
            },
          ),
        ],
        bottom: _isMonthLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Column(
        children: [
          // Month summary strip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total: $_monthTotalPax pax • $pctText% avg utilization',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (_showOfflineChip)
                  const Chip(
                    label: Text('Offline data'),
                    visualDensity: VisualDensity(vertical: -3),
                  ),
              ],
            ),
          ),

          Expanded(
            child: TableCalendar(
              firstDay: _firstDayLimit,
              lastDay: _lastDayLimit,
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              headerVisible: false, // we render our own header above

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
                isTodayHighlighted: true,
              ),
            ),
          ),

          // Month navigation + Today auto behavior:
          // (You said no explicit 'Today' button; user can swipe or use arrows)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back month
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _focusedDay.isAfter(DateTime(_firstDayLimit.year, _firstDayLimit.month, 1))
                      ? () {
                          final prev = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                          _onMonthChanged(prev);
                        }
                      : null,
                ),
                Text(
                  monthLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                // Next month
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: DateTime(_focusedDay.year, _focusedDay.month, 1)
                          .isBefore(DateTime(_lastDayLimit.year, _lastDayLimit.month, 1))
                      ? () {
                          final next = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                          _onMonthChanged(next);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
