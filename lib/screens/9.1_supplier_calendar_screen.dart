// MODULE: SUPPLIER CALENDAR SCREEN (v34)
// Features: Calendar view of PO deliveries by date
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../db/database_helper.dart';
import '9.2_supplier_po_screen.dart';

class SupplierCalendarScreen extends StatefulWidget {
  final int supplierId;
  
  const SupplierCalendarScreen({super.key, required this.supplierId});

  @override
  State<SupplierCalendarScreen> createState() => _SupplierCalendarScreenState();
}

class _SupplierCalendarScreenState extends State<SupplierCalendarScreen> {
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  Map<String, Map<String, dynamic>> _calendarData = {};

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
    
    // Group POs by date (using sentAt or createdAt)
    final data = await db.rawQuery('''
      SELECT DATE(createdAt) as date, COUNT(*) as poCount, SUM(totalAmount) as totalAmount
      FROM purchase_orders
      WHERE vendorId = ? AND DATE(createdAt) BETWEEN ? AND ?
      GROUP BY DATE(createdAt)
    ''', [widget.supplierId, startStr, endStr]);
    
    Map<String, Map<String, dynamic>> calData = {};
    for (var row in data) {
      final dateStr = row['date'] as String?;
      if (dateStr != null) {
        calData[dateStr] = {
          'poCount': (row['poCount'] as num?)?.toInt() ?? 0,
          'totalAmount': (row['totalAmount'] as num?)?.toDouble() ?? 0,
        };
      }
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
      // Show POs for this date (already filters by supplierId in PoScreen)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_calendarData[dateKey]!['poCount']} POs on ${DateFormat('MMM d').format(selectedDay)}')),
      );
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
        title: const Text('PO Calendar'),
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
              rowHeight: 65,
              headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
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
                _legendItem(Colors.teal.shade100, 'PO Day'),
                const SizedBox(width: 24),
                _legendItem(Colors.green.shade100, 'High Value'),
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
    final hasPOs = data != null && (data['poCount'] as int? ?? 0) > 0;
    final totalAmount = (data?['totalAmount'] as num?)?.toDouble() ?? 0;
    
    Color bgColor = Colors.transparent;
    if (hasPOs) {
      bgColor = totalAmount > 10000 ? Colors.green.shade100 : Colors.teal.shade50;
    }
    
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.teal : (isToday ? Colors.blue : Colors.grey.shade300),
          width: isSelected || isToday ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 6,
            child: Text('${day.day}', style: TextStyle(fontSize: 12, color: isSelected ? Colors.teal : Colors.grey.shade700)),
          ),
          if (hasPOs) ...[
            Center(
              child: Text(
                '₹${(totalAmount / 1000).toStringAsFixed(1)}K',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(4)),
                child: Text('${data!['poCount']}', style: const TextStyle(color: Colors.white, fontSize: 9)),
              ),
            ),
          ],
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
