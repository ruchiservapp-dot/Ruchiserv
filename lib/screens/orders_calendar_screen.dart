import 'package:ruchiserv/repositories/order_repository.dart';
import 'package:ruchiserv/core/app_logger.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

import 'orders_list_screen.dart';
// If/when you want AWS back, uncomment the next line and set useAws = true below
// import '../db/aws/aws_api.dart';

class OrderCalendarScreen extends StatefulWidget {
  const OrderCalendarScreen({super.key});

  @override
  State<OrderCalendarScreen> createState() => _OrderCalendarScreenState();
}

class _OrderCalendarScreenState extends State<OrderCalendarScreen>
    with RouteAware {
  // ---- Config you can tweak later (or move to Settings) ----
  static const double _utilizationAmberAt =
      0.50; // >=50% = amber (User request: Green < 50%)
  static const double _utilizationRedAt =
      0.90; // >=90% = red (User request: Red >= 90%)
  int _dailyCapacity = 500; // Dynamic from DB
  static const bool useAws = false; // keep false to avoid previous shape errors

  final DateTime _today = DateTime.now();

  late DateTime _firstDayLimit;
  late DateTime _lastDayLimit;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final CalendarFormat _calendarFormat = CalendarFormat.month;

  // pax map keyed by 'yyyy-MM-dd'
  final Map<String, int> _dailyPax = {};

  // MRP status maps keyed by 'yyyy-MM-dd'
  final Map<String, bool> _dailyMrpRun = {}; // true if any order has MRP run
  final Map<String, bool> _dailyPOSent = {}; // true if all orders have PO sent

  // month stats
  int _monthTotalPax = 0;
  double _monthUtilization = 0.0;

  bool _isMonthLoading = false;
  bool _showOfflineChip = false;
  StreamSubscription? _syncSubscription;

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

    // Phase 3: Real-time UI updates via Sync Stream
    _syncSubscription = OrderRepository().syncStream.listen((event) {
      if (['orders', 'firms'].contains(event.table)) {
        AppLogger.info(
            '⚡ OrderCalendarScreen: Real-time update detected for ${event.table}. Refreshing...');
        if (event.table == 'firms') _loadFirmCapacity();
        _loadCalendarForMonth(_focusedDay);
      }
    });
  }

  Future<void> _loadFirmCapacity() async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm');
    if (firmId != null) {
      final firm = await OrderRepository().getFirm(firmId);
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
    try {
      if (Platform.isMacOS) {
        // On macOS, use shell command to open Calendar app
        await Process.run('open', ['-a', 'Calendar']);
        return;
      } else if (Platform.isIOS) {
        // On iOS, calshow:// works
        final Uri calUrl = Uri.parse('calshow://');
        if (await launchUrl(calUrl, mode: LaunchMode.externalApplication)) {
          return;
        }
      } else if (Platform.isAndroid) {
        // Try Android content deep link
        final Uri androidCalUrl =
            Uri.parse('content://com.android.calendar/time');
        if (await launchUrl(androidCalUrl,
            mode: LaunchMode.externalApplication)) {
          return;
        }
      }
    } catch (_) {
      // Ignore and fall through to web fallback
      AppLogger.error('Caught error: $_');
    }

    // Fallback to Google Calendar in browser
    await launchUrl(Uri.parse('https://calendar.google.com'),
        mode: LaunchMode.externalApplication);
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
    final Map<String, bool> mrpMap = {};
    final Map<String, bool> poMap = {};

    try {
      final sp = await SharedPreferences.getInstance();
      final firmId = sp.getString('last_firm') ?? 'UNKNOWN';

      // 1) Local DB (reliable)
      final all = await OrderRepository().getAllOrdersWithPax(firmId);
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
            : (paxAny is num
                ? paxAny.toInt()
                : int.tryParse(paxAny.toString()) ?? 0);

        final k = _keyOf(d);
        fresh[k] = (fresh[k] ?? 0) + pax;

        // Track MRP status
        final hasMrp = (row['hasMrpRun'] ?? 0) == 1;
        final hasPO = (row['hasPOSent'] ?? 0) == 1;
        if (hasMrp) mrpMap[k] = true;
        if (hasPO) poMap[k] = true;
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
          final dateStr =
              (item['date'] ?? item['order_date'] ?? '').toString().trim();
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
              : (paxAny is num
                  ? paxAny.toInt()
                  : int.tryParse(paxAny.toString()) ?? 0);

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
        _dailyMrpRun
          ..clear()
          ..addAll(mrpMap);
        _dailyPOSent
          ..clear()
          ..addAll(poMap);
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
      _selectedDay =
          DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // No AppBar - MainMenuScreen provides the header
      floatingActionButton: FloatingActionButton.small(
        onPressed: _openSystemCalendar,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.calendar_month_outlined, color: Colors.white),
      ),
      body: Column(
        children: [
          if (_isMonthLoading)
            const LinearProgressIndicator(
                minHeight: 2, backgroundColor: Colors.transparent),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              // Overhead estimates:
              // - ListView padding: 32 vertical
              // - Calendar Card padding: 8 bottom
              // - Header: ~50
              // - DaysOfWeek: 30
              // - Legend: ~80 (Increased for safety)
              // Total overhead approx 200.
              const double estimatedOverhead = 200.0;
              final double availableHeight =
                  constraints.maxHeight - estimatedOverhead;

              // We want 6 rows fixed to ensure consistent height
              final double calculatedRowHeight = availableHeight / 6.0;

              // Clamp to reasonable limits
              final double rowHeight = calculatedRowHeight.clamp(70.0, 400.0);

              return ListView(
                // Scrollable to handle smaller screens or tall calendars
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Calendar Card
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black26
                              : Colors.black.withValues(alpha: 0.04),
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
                      rowHeight: rowHeight, // Dynamic height
                      daysOfWeekHeight: 40,
                      // Ensure 6 weeks are always shown so height parsing is consistent
                      sixWeekMonthsEnforced: true,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month'
                      },

                      // Style Header
                      headerVisible: true,
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        titleTextStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87),
                        leftChevronIcon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[100],
                              shape: BoxShape.circle),
                          child: Icon(Icons.chevron_left,
                              color: isDark ? Colors.white70 : Colors.black54),
                        ),
                        rightChevronIcon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[100],
                              shape: BoxShape.circle),
                          child: Icon(Icons.chevron_right,
                              color: isDark ? Colors.white70 : Colors.black54),
                        ),
                        headerPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),

                      // Style Days of Week
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                        weekendStyle: TextStyle(
                            color: Colors.red[300],
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),

                      selectedDayPredicate: (day) =>
                          _selectedDay != null && isSameDay(_selectedDay, day),

                      onDaySelected: _onDaySelected,
                      onPageChanged: _onMonthChanged,

                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (ctx, day, focused) =>
                            _buildDayCell(ctx, day, focused),
                        todayBuilder: (ctx, day, focused) =>
                            _buildDayCell(ctx, day, focused),
                        selectedBuilder: (ctx, day, focused) =>
                            _buildDayCell(ctx, day, focused),
                        outsideBuilder: (ctx, day, focused) =>
                            _buildDayCell(ctx, day, focused),
                      ),

                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: true,
                        cellMargin: EdgeInsets
                            .zero, // We handle margins/padding in builder
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Legend / Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLegendDot(Colors.green[100]!,
                                AppLocalizations.of(context).utilizationLow),
                            _buildLegendDot(Colors.orange[100]!,
                                AppLocalizations.of(context).utilizationMed),
                            _buildLegendDot(Colors.red[100]!,
                                AppLocalizations.of(context).utilizationHigh),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildMrpLegend(Icons.pending_actions,
                                Colors.blue.shade600, 'MRP Pending'),
                            const SizedBox(width: 24),
                            _buildMrpLegend(Icons.check_circle,
                                Colors.green.shade700, 'PO Sent'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMrpLegend(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ---------- Day Cell ----------
  Widget _buildDayCell(
      BuildContext context, DateTime day, DateTime focusedMonth) {
    final dateKey = _keyOf(day);
    final pax = _dailyPax[dateKey] ?? 0;
    final hasMrpRun = _dailyMrpRun[dateKey] ?? false;
    final hasPOSent = _dailyPOSent[dateKey] ?? false;
    final isOutside = day.month != focusedMonth.month;
    final isToday = isSameDay(day, _today);
    // final isPastDay = _isPast(day); // Optional: dim past days?

    // Modern colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = Colors.transparent;
    Color textColor = isOutside ? Colors.grey.shade300 : Colors.black87;
    FontWeight fontWeight = FontWeight.normal;
    Border? border;

    if (!isOutside) {
      if (pax > 0) {
        final u = pax / (_dailyCapacity > 0 ? _dailyCapacity : 1);
        if (u >= _utilizationRedAt) {
          bgColor = isDark
              ? Colors.red.withValues(alpha: 0.2)
              : const Color(0xFFFFEBEE);
          textColor = isDark ? Colors.red.shade300 : const Color(0xFFC62828);
        } else if (u >= _utilizationAmberAt) {
          bgColor = isDark
              ? Colors.orange.withValues(alpha: 0.2)
              : const Color(0xFFFFF3E0);
          textColor = isDark ? Colors.orange.shade300 : const Color(0xFFEF6C00);
        } else {
          bgColor = isDark
              ? Colors.green.withValues(alpha: 0.2)
              : const Color(0xFFE8F5E9);
          textColor = isDark ? Colors.green.shade300 : const Color(0xFF2E7D32);
        }
        fontWeight = FontWeight.bold;
      }

      if (isToday) {
        border = Border.all(color: Colors.indigo, width: 2);
      } else {
        border = Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade300, width: 1);
      }
    } else {
      border = Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200,
          width: 1);
    }

    return Semantics(
      label:
          'Date ${day.day}, $pax pax${hasMrpRun ? ", MRP ${hasPOSent ? 'Completed' : 'Pending'}" : ""}',
      button: !isOutside,
      child: Container(
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
                  color: isOutside
                      ? Colors.grey[300]
                      : (isSameDay(day, _selectedDay)
                          ? Colors.indigo
                          : Colors.grey[600]),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // MRP Indicator (Top Right) - shows if MRP run or PO sent
            if (!isOutside && hasMrpRun)
              Positioned(
                top: 4,
                right: 6,
                child: Icon(
                  hasPOSent ? Icons.check_circle : Icons.pending_actions,
                  size: 14,
                  color:
                      hasPOSent ? Colors.green.shade700 : Colors.blue.shade600,
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
      ),
    );
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }
}
