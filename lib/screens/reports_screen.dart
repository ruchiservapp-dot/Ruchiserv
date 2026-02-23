// MODULE: REPORTS HUB - LANDING
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'reports/dashboard_view.dart';
import 'reports/detailed_reports_view.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        // Adjust end date to include the full day
        if (_startDate.isAtSameMomentAs(_endDate)) {
          _endDate =
              _endDate.add(const Duration(hours: 23, minutes: 59, seconds: 59));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header for Tabs & Date Range
            Container(
              color: theme.cardColor,
              child: Column(
                children: [
                  // TabBar Row
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue.shade900,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: Colors.blue.shade900,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Dashboard'),
                      Tab(text: 'Detailed Reports'),
                    ],
                  ),
                  const Divider(height: 1),
                  // Date Picker Row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        Text(
                          'Period: ${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.bold),
                        ),
                        InkWell(
                          onTap: _pickDateRange,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_month,
                                    size: 16, color: Colors.blue.shade800),
                                const SizedBox(width: 4),
                                Text('Filter',
                                    style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  DashboardView(startDate: _startDate, endDate: _endDate),
                  DetailedReportsView(
                    initialStartDate: _startDate,
                    initialEndDate: _endDate,
                    onDateRangeChanged: (start, end) {
                      setState(() {
                        _startDate = start;
                        _endDate = end;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
