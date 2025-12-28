// MODULE: SUBCONTRACTOR CALENDAR SCREEN (v34)
// Features: Monthly calendar with assigned order quantities
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../db/database_helper.dart';
import '8.2_subcontractor_order_detail_screen.dart';

class SubcontractorCalendarScreen extends StatefulWidget {
  final int subcontractorId;
  
  const SubcontractorCalendarScreen({super.key, required this.subcontractorId});

  @override
  State<SubcontractorCalendarScreen> createState() => _SubcontractorCalendarScreenState();
}

class _SubcontractorCalendarScreenState extends State<SubcontractorCalendarScreen> {
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Map of date -> {orderCount, totalPax}
  Map<String, Map<String, int>> _calendarData = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadCalendarData();
  }

  String _keyOf(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadCalendarData() async {
    setState(() => _isLoading = true);
    
    final db = await DatabaseHelper().database;
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEnd = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    final startStr = DateFormat('yyyy-MM-dd').format(monthStart);
    final endStr = DateFormat('yyyy-MM-dd').format(monthEnd);
    
    final data = await db.rawQuery('''
      SELECT o.date, COUNT(DISTINCT o.id) as orderCount, SUM(d.pax) as totalPax
      FROM orders o
      JOIN dishes d ON d.orderId = o.id
      WHERE d.isSubcontracted = 1 AND d.subcontractorId = ?
        AND o.date BETWEEN ? AND ?
      GROUP BY o.date
    ''', [widget.subcontractorId, startStr, endStr]);
    
    Map<String, Map<String, int>> calData = {};
    for (var row in data) {
      calData[row['date'] as String] = {
        'orderCount': (row['orderCount'] as num?)?.toInt() ?? 0,
        'totalPax': (row['totalPax'] as num?)?.toInt() ?? 0,
      };
    }
    
    setState(() {
      _calendarData = calData;
      _isLoading = false;
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    
    final dateKey = _keyOf(selectedDay);
    if (_calendarData.containsKey(dateKey)) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SubcontractorOrderDetailScreen(
          date: dateKey,
          subcontractorId: widget.subcontractorId,
        ),
      ));
    }
  }

  void _onMonthChanged(DateTime newFocused) {
    setState(() => _focusedDay = DateTime(newFocused.year, newFocused.month, 1));
    _loadCalendarData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Calendar'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCalendarData),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: TableCalendar(
              firstDay: DateTime(DateTime.now().year - 1),
              lastDay: DateTime(DateTime.now().year + 1),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              onPageChanged: _onMonthChanged,
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              rowHeight: 70,
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (ctx, day, focused) => _buildDayCell(day),
                todayBuilder: (ctx, day, focused) => _buildDayCell(day, isToday: true),
                selectedBuilder: (ctx, day, focused) => _buildDayCell(day, isSelected: true),
              ),
            ),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(Colors.purple.shade100, 'Orders'),
                const SizedBox(width: 24),
                _legendItem(Colors.green.shade100, 'High Volume'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime day, {bool isToday = false, bool isSelected = false}) {
    final dateKey = _keyOf(day);
    final data = _calendarData[dateKey];
    final hasOrders = data != null && (data['orderCount'] ?? 0) > 0;
    final totalPax = data?['totalPax'] ?? 0;
    
    Color bgColor = Colors.transparent;
    if (hasOrders) {
      bgColor = totalPax > 200 ? Colors.green.shade100 : Colors.purple.shade50;
    }
    
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.purple : (isToday ? Colors.blue : Colors.grey.shade300),
          width: isSelected || isToday ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          // Day number
          Positioned(
            top: 4,
            left: 6,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.purple : Colors.grey.shade700,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // Pax count (center)
          if (hasOrders)
            Center(
              child: Text(
                '$totalPax',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
            ),
          // Order count badge
          if (hasOrders)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${data!['orderCount']}',
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }
}
