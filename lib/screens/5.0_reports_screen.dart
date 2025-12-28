// MODULE: REPORTS SCREEN - COMPREHENSIVE
// Last Updated: 2025-12-13 | Features: Orders, Kitchen, Dispatch, HR Reports + Export
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import 'report_preview_page.dart';
import '3.3.2_staff_payroll_screen.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import 'reports/kpi_dashboard_screen.dart';
import 'reports/balance_sheet_screen.dart';
import 'reports/cash_flow_screen.dart';
import 'reports/pl_report_screen.dart';
import 'reports/event_profitability_screen.dart';
import 'finance/salary_disbursement_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedTimeline = 'Week';
  String _selectedCategory = 'Orders'; // Orders, Kitchen, Dispatch, HR
  String _selectedSubReport = 'Summary';
  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = true;
  
  // For expandable detail rows
  final Set<String> _expandedItems = {};
  Map<String, List<Map<String, dynamic>>> _drillDownData = {};

  // Sub-report options per category
  final Map<String, List<String>> _subReports = {
    'Orders': ['Summary', 'By Food Type', 'By Meal Type', 'By Time Slot', 'Top Locations'],
    'Kitchen': ['Production', 'Top Dishes', 'By Category'],
    'Dispatch': ['Delivery Status', 'Capacity'],
    'HR': ['Attendance', 'Overtime'],
    'Finance': ['KPI Dashboard', 'Balance Sheet', 'Cash Flow', 'P&L', 'Event Profit'],
  };

  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _customEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  String get _startDate {
    if (_selectedTimeline == 'Custom') {
      return DateFormat('yyyy-MM-dd').format(_customStartDate);
    }
    final now = DateTime.now();
    DateTime startDate;
    switch (_selectedTimeline) {
      case 'Day': startDate = now; break;
      case 'Week': startDate = now.subtract(const Duration(days: 7)); break;
      case 'Month': startDate = DateTime(now.year, now.month - 1, now.day); break;
      default: startDate = DateTime(now.year - 1, now.month, now.day);
    }
    return DateFormat('yyyy-MM-dd').format(startDate);
  }

  String get _endDate {
    if (_selectedTimeline == 'Custom') {
      return DateFormat('yyyy-MM-dd').format(_customEndDate);
    }
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _customStartDate : _customEndDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStartDate = picked;
          if (_customStartDate.isAfter(_customEndDate)) {
             _customEndDate = _customStartDate;
          }
        } else {
          _customEndDate = picked;
           if (_customEndDate.isBefore(_customStartDate)) {
             _customStartDate = _customEndDate;
          }
        }
      });
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    
    List<Map<String, dynamic>> data = [];
    final db = DatabaseHelper();

    try {
      switch (_selectedCategory) {
        case 'Orders':
          switch (_selectedSubReport) {
            case 'Summary':
              data = await db.getOrderStatusReport(_startDate, _endDate);
              break;
            case 'By Food Type':
              data = await db.getOrdersByFoodTypeReport(_startDate, _endDate);
              break;
            case 'By Meal Type':
              data = await db.getOrdersByMealTypeReport(_startDate, _endDate);
              break;
            case 'By Time Slot':
              data = await db.getDeliveryTimeReport(_startDate, _endDate);
              break;
            case 'Top Locations':
              data = await db.getRevenueByLocationReport(_startDate, _endDate);
              break;
          }
          break;
          
        case 'Kitchen':
          switch (_selectedSubReport) {
            case 'Production':
              data = await db.getKitchenProductionReport(_startDate, _endDate);
              break;
            case 'Top Dishes':
              data = await db.getTopDishesReport(_startDate, _endDate);
              break;
            case 'By Category':
              data = await db.getDishesByCategoryReport(_startDate, _endDate);
              break;
          }
          break;
          
        case 'Dispatch':
          switch (_selectedSubReport) {
            case 'Delivery Status':
              data = await db.getDispatchReport(_startDate, _endDate);
              break;
            case 'Capacity':
              data = await db.getDailyCapacityReport(_startDate, _endDate);
              break;
          }
          break;
          
        case 'HR':
          switch (_selectedSubReport) {
            case 'Attendance':
              data = await db.getHRAttendanceReport(_startDate, _endDate);
              break;
            case 'Overtime':
              data = await db.getHROvertimeReport(_startDate, _endDate);
              break;
          }
          break;
      }
    } catch (e) {
      debugPrint('Report error: $e');
    }

    setState(() {
      _reportData = data;
      _isLoading = false;
    });
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _selectedSubReport = _subReports[category]!.first;
      _expandedItems.clear();
      _drillDownData.clear();
    });
    _loadReportData();
  }

  void _showExportDialog() {
    final headers = _getExportHeaders();
    final rows = _getExportRows();
    
    // Navigate to preview page showing report data first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportPreviewPage(
          title: '$_selectedCategory - $_selectedSubReport',
          subtitle: 'Period: $_startDate to $_endDate',
          headers: headers,
          rows: rows,
          accentColor: _getCategoryColor(_selectedCategory),
        ),
      ),
    );
  }

  List<String> _getExportHeaders() {
    switch (_selectedCategory) {
      case 'Orders':
        switch (_selectedSubReport) {
          case 'Summary': return ['Date', 'Total Orders', 'Confirmed', 'Completed', 'Cancelled', 'Total Pax', 'Revenue'];
          case 'By Food Type': return ['Food Type', 'Order Count', 'Total Pax', 'Revenue'];
          case 'By Meal Type': return ['Meal Type', 'Order Count', 'Total Pax', 'Revenue'];
          case 'By Time Slot': return ['Time Slot', 'Order Count', 'Total Pax'];
          case 'Top Locations': return ['Location', 'Order Count', 'Total Pax', 'Revenue'];
        }
        break;
      case 'Kitchen':
        switch (_selectedSubReport) {
          case 'Production': return ['Date', 'Total Dishes', 'Completed', 'In Progress', 'Pending', 'Total Pax'];
          case 'Top Dishes': return ['Rank', 'Dish Name', 'Category', 'Order Count', 'Total Pax', 'Revenue'];
          case 'By Category': return ['Category', 'Dish Count', 'Revenue'];
        }
        break;
      case 'Dispatch':
        switch (_selectedSubReport) {
          case 'Delivery Status': return ['Date', 'Total Dispatches', 'Delivered', 'In Transit', 'Pending', 'Orders'];
          case 'Capacity': return ['Date', 'Total Pax', 'Veg', 'Non-Veg', 'Orders'];
        }
        break;
      case 'HR':
        switch (_selectedSubReport) {
          case 'Attendance': return ['Staff Name', 'Days Present', 'Total Hours', 'Overtime', 'Geo-Compliant'];
          case 'Overtime': return ['Staff Name', 'Overtime Hours', 'OT Pay'];
        }
        break;
    }
    return [];
  }

  List<List<dynamic>> _getExportRows() {
    List<List<dynamic>> rows = [];
    
    for (var index = 0; index < _reportData.length; index++) {
      final item = _reportData[index];
      final date = item['date'] ?? '';
      
      // 1. Add Parent Row
      List<dynamic> parentRow = [];
      switch (_selectedCategory) {
        case 'Orders':
          switch (_selectedSubReport) {
            case 'Summary': parentRow = [item['date'], item['totalOrders'], item['confirmed'], item['completed'], item['cancelled'], item['totalPax'], item['revenue']]; break;
            case 'By Food Type': parentRow = [item['foodType'], item['orderCount'], item['totalPax'], item['revenue']]; break;
            case 'By Meal Type': parentRow = [item['mealType'], item['orderCount'], item['totalPax'], item['revenue']]; break;
            case 'By Time Slot': parentRow = [item['timeSlot'], item['orderCount'], item['totalPax']]; break;
            case 'Top Locations': parentRow = [item['location'], item['orderCount'], item['totalPax'], item['revenue']]; break;
          }
          break;
        case 'Kitchen':
          switch (_selectedSubReport) {
            case 'Production': parentRow = [item['date'], item['totalDishes'], item['completed'], item['inProgress'], item['pending'], item['totalPax']]; break;
            case 'Top Dishes': parentRow = [index + 1, item['name'], item['category'], item['orderCount'], item['totalPax'], item['totalRevenue']]; break;
            case 'By Category': parentRow = [item['category'], item['dishCount'], item['totalRevenue']]; break;
          }
          break;
        case 'Dispatch':
           switch (_selectedSubReport) {
            case 'Delivery Status': parentRow = [item['date'], item['totalDispatches'], item['delivered'], item['inTransit'], item['pending'], item['ordersCount']]; break;
            case 'Capacity': parentRow = [item['date'], item['totalPax'], item['vegPax'], item['nonVegPax'], item['orderCount']]; break;
          }
          break;
        case 'HR':
          switch (_selectedSubReport) {
            case 'Attendance': parentRow = [item['name'], item['daysPresent'], item['totalHours'], item['totalOvertime'], item['geoFenceCompliant']]; break;
             case 'Overtime': parentRow = [item['name'], item['totalOT'], item['otPay']]; break;
          }
          break;
      }
      if (parentRow.isNotEmpty) rows.add(parentRow);

      // 2. Add Child Rows (if expanded)
      if (_selectedCategory == 'Orders' && _selectedSubReport == 'Summary' && _expandedItems.contains(date)) {
        if (_drillDownData.containsKey(date)) {
          for (var order in _drillDownData[date]!) {
            // Add order row with full details
            rows.add([
              '', // Indent indicator
              '#${order['id']} - ${order['customerName']}',
              '${order['mealType'] ?? ''} | ${order['foodType'] ?? 'Veg'}',
              order['venue'] ?? '',
              order['mobile'] ?? '',
              order['totalPax'] ?? 0,
              order['finalAmount'] ?? order['grandTotal'] ?? 0
            ]);
            
            // 3. Add Dish Rows (if order expanded)
            final orderKey = 'order_${order['id']}';
            if (_expandedItems.contains(orderKey) && _drillDownData.containsKey(orderKey)) {
              for (var dish in _drillDownData[orderKey]!) {
                 rows.add([
                  '', '', // Double Indent
                  '  ↳ ${dish['name']}',
                  dish['foodType'] ?? 'Veg',
                  '',
                  dish['pax'] ?? 0,
                  (dish['pricePerPlate'] ?? 0) * (dish['pax'] ?? 1)
                ]);
              }
            }
          }
        }
      } 
      else if (_selectedCategory == 'Kitchen' && _selectedSubReport == 'Production' && _expandedItems.contains(date)) {
        final key = 'kitchen_$date';
        if (_drillDownData.containsKey(key)) {
          for (var dish in _drillDownData[key]!) {
             final status = dish['orderStatus'] == 'Completed' ? 'Completed' : 'Pending';
             rows.add([
              '',
              dish['name'],
              status,
              '',
              '',
              dish['pax'] ?? 0
            ]);
          }
        }
      }
      else if (_selectedCategory == 'Dispatch' && _selectedSubReport == 'Delivery Status' && _expandedItems.contains(date)) {
        final key = 'dispatch_$date';
         if (_drillDownData.containsKey(key)) {
          for (var dispatch in _drillDownData[key]!) {
             rows.add([
              '',
              '#${dispatch['id']} - ${dispatch['location']}',
              dispatch['status'] ?? 'PENDING',
              '',
              '',
              ''
            ]);
          }
        }
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      floatingActionButton: _reportData.isNotEmpty ? FloatingActionButton.extended(
        onPressed: _showExportDialog,
        icon: const Icon(Icons.download),
        label: const Text('Export'),
        backgroundColor: _getCategoryColor(_selectedCategory),
      ) : null,
      body: Column(
        children: [
          // Controls Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline Selector
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(AppLocalizations.of(context)!.periodLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedTimeline,
                          underline: const SizedBox(),
                          items: [
                            AppLocalizations.of(context)!.day,
                            AppLocalizations.of(context)!.week,
                            AppLocalizations.of(context)!.month,
                            AppLocalizations.of(context)!.year,
                            'Custom',
                          ]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedTimeline = val);
                              if (val != 'Custom') {
                                 _loadReportData();
                              }
                            }
                          },
                        ),
                        if (_selectedTimeline != 'Custom') ...[
                           const SizedBox(width: 12),
                           Text('$_startDate to $_endDate', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],

                    const Spacer(),
                    if (_selectedCategory == 'HR')
                      TextButton.icon(
                        onPressed: () => Navigator.push(context, 
                          MaterialPageRoute(builder: (_) => const StaffPayrollScreen())),
                        icon: const Icon(Icons.payments, size: 18),
                        label: Text(AppLocalizations.of(context)!.payroll),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadReportData,
                    ),
                  ],
                ),
                if (_selectedTimeline == 'Custom')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(true),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('dd MMM yyyy').format(_customStartDate)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('to'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(false),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('dd MMM yyyy').format(_customEndDate)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _loadReportData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getCategoryColor(_selectedCategory),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Filter'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
                const Divider(height: 16),
                
                // Category Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Orders', 'Kitchen', 'Dispatch', 'HR', 'Finance'].map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getCategoryIcon(cat),
                                size: 16,
                                color: isSelected ? Colors.white : _getCategoryColor(cat),
                              ),
                              const SizedBox(width: 4),
                              Text(cat),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: _getCategoryColor(cat),
                          onSelected: (_) => _selectCategory(cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Sub-Report Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _subReports[_selectedCategory]!.map((sub) {
                      final isSelected = _selectedSubReport == sub;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(sub, style: TextStyle(fontSize: 12)),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedSubReport = sub);
                            _loadReportData();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Report Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context)!.noDataSelectedPeriod, 
                              style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : _buildReportContent(),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Orders': return Icons.receipt_long;
      case 'Kitchen': return Icons.restaurant;
      case 'Dispatch': return Icons.local_shipping;
      case 'HR': return Icons.people;
      case 'Finance': return Icons.account_balance;
      default: return Icons.analytics;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Orders': return Colors.blue;
      case 'Kitchen': return Colors.orange;
      case 'Dispatch': return Colors.green;
      case 'HR': return Colors.purple;
      case 'Finance': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  Widget _buildReportContent() {
    switch (_selectedCategory) {
      case 'Orders': return _buildOrdersReport();
      case 'Kitchen': return _buildKitchenReport();
      case 'Dispatch': return _buildDispatchReport();
      case 'HR': return _buildHRReport();
      case 'Finance': return _buildFinanceReport();
      default: return const SizedBox();
    }
  }

  // ============== FINANCE REPORTS ==============
  
  Widget _buildFinanceReport() {
    // For Finance, we navigate to dedicated screens instead of showing data here
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Finance report navigation tiles
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildFinanceTile(
                  'KPI Dashboard',
                  'Revenue, Margin, Orders',
                  Icons.dashboard,
                  Colors.deepPurple,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KPIDashboardScreen())),
                ),
                _buildFinanceTile(
                  'Balance Sheet',
                  'Assets & Liabilities',
                  Icons.account_balance,
                  Colors.indigo,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BalanceSheetScreen())),
                ),
                _buildFinanceTile(
                  'Cash Flow',
                  'Operating Cash',
                  Icons.waterfall_chart,
                  Colors.teal,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashFlowScreen())),
                ),
                _buildFinanceTile(
                  'P&L Report',
                  'Profit & Loss',
                  Icons.trending_up,
                  Colors.green,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PLReportScreen())),
                ),
                _buildFinanceTile(
                  'Event Profit',
                  'Per-Order Analysis',
                  Icons.event_note,
                  Colors.purple,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventProfitabilityScreen())),
                ),
                _buildFinanceTile(
                  'Salary',
                  'Disbursement',
                  Icons.payments,
                  Colors.pink,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalaryDisbursementScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // ============== ORDERS REPORTS ==============
  
  Widget _buildOrdersReport() {
    switch (_selectedSubReport) {
      case 'Summary': return _buildOrderSummaryReport();
      case 'By Food Type': return _buildFoodTypeReport();
      case 'By Meal Type': return _buildMealTypeReport();
      case 'By Time Slot': return _buildTimeSlotReport();
      case 'Top Locations': return _buildLocationReport();
      default: return const SizedBox();
    }
  }

  void _toggleExpandAll() {
    final allKeys = _reportData.map((e) => e['date']?.toString() ?? '').where((e) => e.isNotEmpty).toSet();
    final allExpanded = _expandedItems.containsAll(allKeys);
    
    setState(() {
      if (allExpanded) {
        _expandedItems.removeAll(allKeys);
      } else {
        _expandedItems.addAll(allKeys);
        for (var date in allKeys) {
          _loadOrdersForDate(date);
        }
      }
    });
  }

  Widget _buildOrderSummaryReport() {
    // Calculate totals
    int totalOrders = 0, totalConfirmed = 0, totalCompleted = 0, totalCancelled = 0;
    double totalRevenue = 0;
    int totalPax = 0;
    
    for (var item in _reportData) {
      totalOrders += (item['totalOrders'] as num?)?.toInt() ?? 0;
      totalConfirmed += (item['confirmed'] as num?)?.toInt() ?? 0;
      totalCompleted += (item['completed'] as num?)?.toInt() ?? 0;
      totalCancelled += (item['cancelled'] as num?)?.toInt() ?? 0;
      totalRevenue += (item['revenue'] as num?)?.toDouble() ?? 0;
      totalPax += (item['totalPax'] as num?)?.toInt() ?? 0;
    }

    final allKeys = _reportData.map((e) => e['date']?.toString() ?? '').where((e) => e.isNotEmpty).toSet();
    final allExpanded = _reportData.isNotEmpty && _expandedItems.containsAll(allKeys);
    
    return Column(
      children: [
        _buildSummaryHeader([
          _SummaryItem(AppLocalizations.of(context)!.totalOrders, totalOrders.toString(), Icons.receipt_long, Colors.blue),
          _SummaryItem(AppLocalizations.of(context)!.confirmed, totalConfirmed.toString(), Icons.pending, Colors.orange),
          _SummaryItem(AppLocalizations.of(context)!.completed, totalCompleted.toString(), Icons.check_circle, Colors.green),
          _SummaryItem(AppLocalizations.of(context)!.cancelled, totalCancelled.toString(), Icons.cancel, Colors.red),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(AppLocalizations.of(context)!.totalPax(totalPax), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Text('${AppLocalizations.of(context)!.revenue}: ₹${totalRevenue.toStringAsFixed(0)}', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              const Spacer(),
              TextButton.icon(
                onPressed: _toggleExpandAll,
                icon: Icon(allExpanded ? Icons.unfold_less : Icons.unfold_more, size: 18),
                label: Text(allExpanded ? 'Collapse All' : 'Expand All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _reportData.length,
            itemBuilder: (context, index) {
              final item = _reportData[index];
              final date = item['date'] ?? '';
              final orders = (item['totalOrders'] as num?)?.toInt() ?? 0;
              final completed = (item['completed'] as num?)?.toInt() ?? 0;
              final revenue = (item['revenue'] as num?)?.toDouble() ?? 0;
              final pax = (item['totalPax'] as num?)?.toInt() ?? 0;
              final isExpanded = _expandedItems.contains(date);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpansionTile(
                  key: Key(date),
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      if (expanded) {
                        _expandedItems.add(date);
                        _loadOrdersForDate(date);
                      } else {
                        _expandedItems.remove(date);
                      }
                    });
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(DateFormat('dd').format(DateTime.parse(date)),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  title: Text(DateFormat('EEE, MMM d').format(DateTime.parse(date))),
                  subtitle: Text('$orders orders | $pax pax | $completed completed'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${revenue.toStringAsFixed(0)}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(width: 8),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                  children: [
                    if (_drillDownData.containsKey(date))
                      ..._drillDownData[date]!.map((order) {
                        final orderId = order['id'];
                        final orderKey = 'order_$orderId';
                        final isOrderExpanded = _expandedItems.contains(orderKey);

                        return ExpansionTile(
                          key: Key(orderKey),
                          initiallyExpanded: isOrderExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              if (expanded) {
                                _expandedItems.add(orderKey);
                                // Auto-load dishes when order is expanded
                                _loadDishesForOrder(orderId, orderKey);
                              } else {
                                _expandedItems.remove(orderKey);
                              }
                            });
                          },
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('#$orderId', style: TextStyle(fontSize: 10, color: Colors.blue.shade800)),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(order['customerName'] ?? 'Customer', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (order['foodType'] == 'Non-Veg') ? Colors.red.shade100 : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(order['foodType'] ?? 'Veg', 
                                  style: TextStyle(fontSize: 9, color: (order['foodType'] == 'Non-Veg') ? Colors.red.shade700 : Colors.green.shade700)),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.people, size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text('${order['totalPax'] ?? 0} pax', style: const TextStyle(fontSize: 11)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.restaurant_menu, size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text('${order['mealType'] ?? 'N/A'}', style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                              if (order['venue'] != null && order['venue'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(order['venue'], style: const TextStyle(fontSize: 11, color: Colors.grey))),
                                    ],
                                  ),
                                ),
                              if (order['mobile'] != null && order['mobile'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.phone, size: 12, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text('${order['mobile']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${(order['finalAmount'] ?? order['grandTotal'] ?? 0).toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                              Icon(isOrderExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                            ],
                          ),
                          children: [
                             if (_drillDownData.containsKey(orderKey))
                              Container(
                                color: Colors.grey.shade50,
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                child: Column(
                                  children: [
                                    const Row(
                                      children: [
                                        Expanded(child: Text('Dish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                        Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        SizedBox(width: 16),
                                        Text('Pax', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      ],
                                    ),
                                    const Divider(height: 8),
                                    ..._drillDownData[orderKey]!.map((dish) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(dish['name'] ?? 'Unknown', style: const TextStyle(fontSize: 12))),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (dish['foodType'] == 'Non-Veg') ? Colors.red.shade100 : Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                            child: Text(dish['foodType'] ?? 'Veg', 
                                              style: TextStyle(fontSize: 10, color: (dish['foodType'] == 'Non-Veg') ? Colors.red : Colors.green)),
                                          ),
                                          const SizedBox(width: 16),
                                          Text('${dish['pax'] ?? 0}', style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    )).toList(),
                                  ],
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                              ),
                          ],
                        );
                      }).toList()
                    else
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _loadOrdersForDate(String date) async {
    if (_drillDownData.containsKey(date)) return;
    final orders = await DatabaseHelper().getOrdersByDate(date);
    if (mounted) {
      setState(() {
        _drillDownData[date] = orders;
      });
    }
  }

  Future<void> _loadDishesForOrder(int orderId, String key) async {
    if (_drillDownData.containsKey(key)) return;
    final dishes = await DatabaseHelper().getDishesForOrder(orderId);
    if (mounted) {
      setState(() {
        _drillDownData[key] = dishes;
      });
    }
  }

  Widget _buildFoodTypeReport() {
    return _buildExpandableTypeReport(
      data: _reportData,
      labelKey: 'foodType',
      typeKeyForDb: 'foodType',
      colors: {'Veg': Colors.green, 'Non-Veg': Colors.red, 'Both': Colors.orange},
    );
  }

  Widget _buildMealTypeReport() {
    return _buildExpandableTypeReport(
      data: _reportData,
      labelKey: 'mealType',
      typeKeyForDb: 'mealType',
      colors: {
        'Breakfast': Colors.amber,
        'Lunch': Colors.orange,
        'Dinner': Colors.purple,
        'Snacks': Colors.teal,
      },
    );
  }

  /// Expandable report for Food Type / Meal Type with drill-down to orders and dishes
  Widget _buildExpandableTypeReport({
    required List<Map<String, dynamic>> data,
    required String labelKey,
    required String typeKeyForDb,
    Map<String, Color>? colors,
  }) {
    // Calculate totals
    int totalOrders = 0;
    double totalRevenue = 0;
    for (var item in data) {
      totalOrders += (item['orderCount'] as num?)?.toInt() ?? 0;
      totalRevenue += (item['revenue'] as num?)?.toDouble() ?? 0;
    }

    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('$totalOrders', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('Total Orders', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Column(
                children: [
                  Text('₹${totalRevenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                  const Text('Revenue', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        // Expandable list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              final label = item[labelKey]?.toString() ?? 'Unknown';
              final orderCount = (item['orderCount'] as num?)?.toInt() ?? 0;
              final revenue = (item['revenue'] as num?)?.toDouble() ?? 0;
              final totalPax = (item['totalPax'] as num?)?.toInt() ?? 0;
              final percentage = totalOrders > 0 ? (orderCount / totalOrders * 100) : 0;
              
              final color = colors?[label] ?? Colors.primaries[index % Colors.primaries.length];
              final typeKey = '${typeKeyForDb}_$label';
              final isExpanded = _expandedItems.contains(typeKey);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ExpansionTile(
                  key: Key(typeKey),
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      if (expanded) {
                        _expandedItems.add(typeKey);
                        _loadOrdersByType(typeKeyForDb, label, typeKey);
                      } else {
                        _expandedItems.remove(typeKey);
                      }
                    });
                  },
                  leading: CircleAvatar(
                    backgroundColor: color,
                    child: Text('${percentage.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                      const SizedBox(height: 4),
                      Text('$orderCount orders | $totalPax pax'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${revenue.toStringAsFixed(0)}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(width: 4),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                  children: [
                    if (_drillDownData.containsKey(typeKey))
                      ..._drillDownData[typeKey]!.map((order) {
                        final orderId = order['id'];
                        final orderKey = 'type_order_$orderId';
                        final isOrderExpanded = _expandedItems.contains(orderKey);

                        return ExpansionTile(
                          key: Key(orderKey),
                          initiallyExpanded: isOrderExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              if (expanded) {
                                _expandedItems.add(orderKey);
                                _loadDishesForOrder(orderId, orderKey);
                              } else {
                                _expandedItems.remove(orderKey);
                              }
                            });
                          },
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('#$orderId', style: TextStyle(fontSize: 10, color: color)),
                          ),
                          title: Text(order['customerName'] ?? 'Customer', style: const TextStyle(fontSize: 13)),
                          subtitle: Text('${order['date']} | ${order['totalPax'] ?? 0} pax | ${order['venue'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₹${(order['finalAmount'] ?? 0).toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                              Icon(isOrderExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                            ],
                          ),
                          children: [
                            if (_drillDownData.containsKey(orderKey))
                              Container(
                                color: Colors.grey.shade50,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: _drillDownData[orderKey]!.map((dish) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.restaurant, size: 14, color: dish['foodType'] == 'Non-Veg' ? Colors.red : Colors.green),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(dish['name'] ?? 'Unknown', style: const TextStyle(fontSize: 12))),
                                        Text('${dish['pax'] ?? 0} pax', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  )).toList(),
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                              ),
                          ],
                        );
                      }).toList()
                    else
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _loadOrdersByType(String typeKey, String typeValue, String key) async {
    if (_drillDownData.containsKey(key)) return;
    final db = await DatabaseHelper().database;
    final orders = await db.query('orders',
      where: "$typeKey = ? AND date BETWEEN ? AND ?",
      whereArgs: [typeValue, _startDate, _endDate],
      orderBy: 'date DESC',
    );
    if (mounted) {
      setState(() => _drillDownData[key] = orders);
    }
  }

  Widget _buildTimeSlotReport() {
    return _buildPieListReport(
      data: _reportData,
      labelKey: 'timeSlot',
      valueKey: 'orderCount',
      secondaryKey: 'totalPax',
      colors: {
        'Morning (6-12)': Colors.amber,
        'Afternoon (12-5)': Colors.orange,
        'Evening (5-10)': Colors.indigo,
      },
    );
  }

  Widget _buildLocationReport() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _reportData.length,
      itemBuilder: (context, index) {
        final item = _reportData[index];
        final location = item['location'] ?? 'Unknown';
        final orders = (item['orderCount'] as num?)?.toInt() ?? 0;
        final revenue = (item['revenue'] as num?)?.toDouble() ?? 0;
        final pax = (item['totalPax'] as num?)?.toInt() ?? 0;
        
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.2),
              child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            title: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('$orders orders | $pax pax'),
            trailing: Text('₹${revenue.toStringAsFixed(0)}', 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ),
        );
      },
    );
  }

  // ============== KITCHEN REPORTS ==============
  
  Widget _buildKitchenReport() {
    switch (_selectedSubReport) {
      case 'Production': return _buildProductionReport();
      case 'Top Dishes': return _buildTopDishesReport();
      case 'By Category': return _buildCategoryReport();
      default: return const SizedBox();
    }
  }

  Widget _buildProductionReport() {
    int totalDishes = 0, completed = 0, inProgress = 0, pending = 0;
    
    for (var item in _reportData) {
      totalDishes += (item['totalDishes'] as num?)?.toInt() ?? 0;
      completed += (item['completed'] as num?)?.toInt() ?? 0;
      inProgress += (item['inProgress'] as num?)?.toInt() ?? 0;
      pending += (item['pending'] as num?)?.toInt() ?? 0;
    }

    final allKeys = _reportData.map((e) => e['date']?.toString() ?? '').where((e) => e.isNotEmpty).toSet();
    final allExpanded = _reportData.isNotEmpty && _expandedItems.containsAll(allKeys);
    
    return Column(
      children: [
        _buildSummaryHeader([
          _SummaryItem('Total Dishes', totalDishes.toString(), Icons.restaurant, Colors.blue),
          _SummaryItem(AppLocalizations.of(context)!.completed, completed.toString(), Icons.check_circle, Colors.green),
          _SummaryItem(AppLocalizations.of(context)!.inProgress, inProgress.toString(), Icons.pending, Colors.orange),
          _SummaryItem(AppLocalizations.of(context)!.pending, pending.toString(), Icons.schedule, Colors.grey),
        ]),
         Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _toggleExpandAll,
                icon: Icon(allExpanded ? Icons.unfold_less : Icons.unfold_more, size: 18),
                label: Text(allExpanded ? 'Collapse All' : 'Expand All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _reportData.length,
            itemBuilder: (context, index) {
              final item = _reportData[index];
              final date = item['date'] ?? '';
              final total = (item['totalDishes'] as num?)?.toInt() ?? 0;
              final done = (item['completed'] as num?)?.toInt() ?? 0;
              final pax = (item['totalPax'] as num?)?.toInt() ?? 0;
               final isExpanded = _expandedItems.contains(date);
              
              final progress = total > 0 ? done / total : 0.0;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpansionTile(
                  key: Key('prod_$date'), // Unique key prefix
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      if (expanded) {
                        _expandedItems.add(date);
                        _loadProductionDetails(date);
                      } else {
                        _expandedItems.remove(date);
                      }
                    });
                  },
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation(Colors.green),
                      ),
                      Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                  title: Text(DateFormat('EEE, MMM d').format(DateTime.parse(date))),
                  subtitle: Text('$done/$total dishes | $pax pax'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       Icon(
                        progress == 1 ? Icons.check_circle : Icons.pending,
                        color: progress == 1 ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                  children: [
                    if (_drillDownData.containsKey('kitchen_$date'))
                      Container(
                        height: 200, // Limit height
                         color: Colors.grey.shade50,
                        child: ListView.builder(
                          itemCount: _drillDownData['kitchen_$date']!.length,
                          itemBuilder: (ctx, i) {
                            final dish = _drillDownData['kitchen_$date']![i];
                            final status = dish['orderStatus'] == 'Completed' ? 'Completed' : 'Pending';
                             return ListTile(
                              dense: true,
                              title: Text(dish['name'] ?? 'Unknown Dish'),
                              subtitle: Text('${dish['customerName'] ?? 'Unknown'} | ${dish['pax'] ?? 0} pax'),
                              trailing: Chip(
                                label: Text(status, style: const TextStyle(fontSize: 10)),
                                backgroundColor: status == 'Completed' ? Colors.green.shade100 : Colors.orange.shade100,
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          },
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _loadProductionDetails(String date) async {
    final key = 'kitchen_$date';
    if (_drillDownData.containsKey(key)) return;
    final dishes = await DatabaseHelper().getDishesForDate(date);
    if (mounted) {
      setState(() {
        _drillDownData[key] = dishes;
      });
    }
  }

  Widget _buildTopDishesReport() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _reportData.length,
      itemBuilder: (context, index) {
        final item = _reportData[index];
        final name = item['name'] ?? 'Unknown';
        final category = item['category'] ?? '';
        final orders = (item['orderCount'] as num?)?.toInt() ?? 0;
        final pax = (item['totalPax'] as num?)?.toInt() ?? 0;
        final revenue = (item['totalRevenue'] as num?)?.toDouble() ?? 0;
        final dishKey = 'dish_$name';
        final isExpanded = _expandedItems.contains(dishKey);
        
        return Card(
          child: ExpansionTile(
            key: Key(dishKey),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedItems.add(dishKey);
                  _loadIngredientsForDish(name, dishKey);
                } else {
                  _expandedItems.remove(dishKey);
                }
              });
            },
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$category | $orders orders | $pax pax'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹${revenue.toStringAsFixed(0)}', 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(width: 8),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            children: [
              Container(
                color: Colors.orange.shade50,
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ingredients (per pax)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange.shade800)),
                    const SizedBox(height: 8),
                    if (_drillDownData.containsKey(dishKey))
                      ..._drillDownData[dishKey]!.map((ing) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.eco, size: 12, color: Colors.green.shade600),
                            const SizedBox(width: 8),
                            Expanded(child: Text(ing['ingredientName'] ?? 'Unknown', style: const TextStyle(fontSize: 12))),
                            Text('${(ing['scaledQuantity'] as num?)?.toStringAsFixed(2) ?? '?'} ${ing['unit'] ?? 'kg'}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          ],
                        ),
                      )).toList()
                    else
                      const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadIngredientsForDish(String dishName, String key) async {
    if (_drillDownData.containsKey(key)) return;
    // Load ingredients for 1 pax
    final ingredients = await DatabaseHelper().getRecipeForDishByName(dishName, 1);
    if (mounted) {
      setState(() {
        _drillDownData[key] = ingredients;
      });
    }
  }

  Widget _buildCategoryReport() {
    return _buildPieListReport(
      data: _reportData,
      labelKey: 'category',
      valueKey: 'dishCount',
      secondaryKey: 'totalRevenue',
      colors: {
        'Starters': Colors.amber,
        'Main Course': Colors.orange,
        'Desserts': Colors.pink,
        'Beverages': Colors.blue,
        'Specialties': Colors.purple,
      },
    );
  }

  // ============== DISPATCH REPORTS ==============
  
  Widget _buildDispatchReport() {
    switch (_selectedSubReport) {
      case 'Delivery Status': return _buildDeliveryStatusReport();
      case 'Capacity': return _buildCapacityReport();
      default: return const SizedBox();
    }
  }

  Widget _buildDeliveryStatusReport() {
    int totalDishes = 0, completed = 0, inProgress = 0, pending = 0;
    int totalDispatches = 0, delivered = 0, inTransit = 0, pendingD = 0;
    
    for (var item in _reportData) {
      totalDispatches += (item['totalDispatches'] as num?)?.toInt() ?? 0;
      delivered += (item['delivered'] as num?)?.toInt() ?? 0;
      inTransit += (item['inTransit'] as num?)?.toInt() ?? 0;
      pendingD += (item['pending'] as num?)?.toInt() ?? 0;
    }

    final allKeys = _reportData.map((e) => e['date']?.toString() ?? '').where((e) => e.isNotEmpty).toSet();
    final allExpanded = _reportData.isNotEmpty && _expandedItems.containsAll(allKeys);
    
    return Column(
      children: [
        _buildSummaryHeader([
          _SummaryItem(AppLocalizations.of(context)!.totalDispatches, totalDispatches.toString(), Icons.local_shipping, Colors.blue),
          _SummaryItem(AppLocalizations.of(context)!.delivered, delivered.toString(), Icons.check_circle, Colors.green),
          _SummaryItem(AppLocalizations.of(context)!.inTransit, inTransit.toString(), Icons.directions_car, Colors.orange),
          _SummaryItem(AppLocalizations.of(context)!.pending, pendingD.toString(), Icons.pending, Colors.grey),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _toggleExpandAll,
                icon: Icon(allExpanded ? Icons.unfold_less : Icons.unfold_more, size: 18),
                label: Text(allExpanded ? 'Collapse All' : 'Expand All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _reportData.length,
            itemBuilder: (context, index) {
              final item = _reportData[index];
              final date = item['date'] ?? '';
              final total = (item['totalDispatches'] as num?)?.toInt() ?? 0;
              final done = (item['delivered'] as num?)?.toInt() ?? 0;
              final orders = (item['ordersCount'] as num?)?.toInt() ?? 0;
              final isExpanded = _expandedItems.contains(date);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpansionTile(
                  key: Key('dispatch_$date'),
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      if (expanded) {
                        _expandedItems.add(date);
                        _loadDispatchDetails(date);
                      } else {
                        _expandedItems.remove(date);
                      }
                    });
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.local_shipping, color: Colors.white),
                  ),
                  title: Text(DateFormat('EEE, MMM d').format(DateTime.parse(date))),
                  subtitle: Text('$total dispatches | $orders orders'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text('$done delivered'),
                        backgroundColor: Colors.green.withOpacity(0.2),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                  children: [
                    if (_drillDownData.containsKey('dispatch_$date'))
                      Container(
                        color: Colors.grey.shade50,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _drillDownData['dispatch_$date']!.length,
                          itemBuilder: (ctx, i) {
                            final dispatch = _drillDownData['dispatch_$date']![i];
                            final status = dispatch['status'] ?? 'PENDING';
                            return ListTile(
                              dense: true,
                              title: Text('Dispatch #${dispatch['id']}'),
                              subtitle: Text('${dispatch['customerName'] ?? 'Unknown'} | ${dispatch['location'] ?? 'N/A'}'),
                              trailing: Text(status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            );
                          },
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _loadDispatchDetails(String date) async {
    final key = 'dispatch_$date';
    if (_drillDownData.containsKey(key)) return;
    final dispatches = await DatabaseHelper().getDispatchesForDate(date);
    if (mounted) {
      setState(() {
        _drillDownData[key] = dispatches;
      });
    }
  }


  Widget _buildCapacityReport() {
    int totalPax = 0, vegPax = 0, nonVegPax = 0, totalOrders = 0;
    
    for (var item in _reportData) {
      totalPax += (item['totalPax'] as num?)?.toInt() ?? 0;
      vegPax += (item['vegPax'] as num?)?.toInt() ?? 0;
      nonVegPax += (item['nonVegPax'] as num?)?.toInt() ?? 0;
      totalOrders += (item['orderCount'] as num?)?.toInt() ?? 0;
    }
    
    return Column(
      children: [
        _buildSummaryHeader([
          _SummaryItem('Total Pax', totalPax.toString(), Icons.people, Colors.blue),
          _SummaryItem('Veg', vegPax.toString(), Icons.eco, Colors.green),
          _SummaryItem('Non-Veg', nonVegPax.toString(), Icons.restaurant, Colors.red),
          _SummaryItem('Orders', totalOrders.toString(), Icons.receipt, Colors.purple),
        ]),
        Expanded(
          child: ListView.builder(
            itemCount: _reportData.length,
            itemBuilder: (context, index) {
              final item = _reportData[index];
              final date = item['date'] ?? '';
              final pax = (item['totalPax'] as num?)?.toInt() ?? 0;
              final veg = (item['vegPax'] as num?)?.toInt() ?? 0;
              final nonVeg = (item['nonVegPax'] as num?)?.toInt() ?? 0;
              final orders = (item['orderCount'] as num?)?.toInt() ?? 0;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text('$pax', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  title: Text(DateFormat('EEE, MMM d').format(DateTime.parse(date))),
                  subtitle: Row(
                    children: [
                      Chip(label: Text('🥗 $veg'), backgroundColor: Colors.green.withOpacity(0.2)),
                      const SizedBox(width: 4),
                      Chip(label: Text('🍖 $nonVeg'), backgroundColor: Colors.red.withOpacity(0.2)),
                    ],
                  ),
                  trailing: Text('$orders orders'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============== HR REPORTS ==============
  
  Widget _buildHRReport() {
    switch (_selectedSubReport) {
      case 'Attendance': return _buildHRAttendanceReport();
      case 'Overtime': return _buildHROvertimeReport();
      default: return const SizedBox();
    }
  }

  Widget _buildHRAttendanceReport() {
    int staffCount = _reportData.length;
    int totalDays = 0;
    double totalHours = 0;
    double totalOT = 0;
    
    for (var item in _reportData) {
      totalDays += (item['daysPresent'] as num?)?.toInt() ?? 0;
      totalHours += (item['totalHours'] as num?)?.toDouble() ?? 0;
      totalOT += (item['totalOvertime'] as num?)?.toDouble() ?? 0;
    }
    
    return Column(
      children: [
        _buildSummaryHeader([
          _SummaryItem(AppLocalizations.of(context)!.staff, staffCount.toString(), Icons.people, Colors.purple),
          _SummaryItem(AppLocalizations.of(context)!.attendance, totalDays.toString(), Icons.calendar_today, Colors.blue),
          _SummaryItem(AppLocalizations.of(context)!.hours, totalHours.toStringAsFixed(0), Icons.access_time, Colors.green),
          _SummaryItem(AppLocalizations.of(context)!.overtime, totalOT.toStringAsFixed(1), Icons.more_time, Colors.orange),
        ]),
        Expanded(
          child: ListView.builder(
            itemCount: _reportData.length,
            itemBuilder: (context, index) {
              final item = _reportData[index];
              final staffId = item['staffId'] ?? item['id'];
              final name = item['name'] ?? 'Unknown';
              final days = (item['daysPresent'] as num?)?.toInt() ?? 0;
              final hours = (item['totalHours'] as num?)?.toDouble() ?? 0;
              final ot = (item['totalOvertime'] as num?)?.toDouble() ?? 0;
              final geoCompliant = (item['geoFenceCompliant'] as num?)?.toInt() ?? 0;
              final staffKey = 'staff_$staffId';
              final isExpanded = _expandedItems.contains(staffKey);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpansionTile(
                  key: Key(staffKey),
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      if (expanded) {
                        _expandedItems.add(staffKey);
                        _loadAttendanceForStaff(staffId, staffKey);
                      } else {
                        _expandedItems.remove(staffKey);
                      }
                    });
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple,
                    child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$days days | ${hours.toStringAsFixed(1)}h${ot > 0 ? ' (+${ot.toStringAsFixed(1)} OT)' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (geoCompliant > 0)
                        Icon(Icons.location_on, size: 18, color: geoCompliant == days ? Colors.green : Colors.orange),
                      const SizedBox(width: 4),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                  children: [
                    Container(
                      color: Colors.purple.shade50,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Attendance Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple.shade800)),
                          const SizedBox(height: 8),
                          if (_drillDownData.containsKey(staffKey))
                            ..._drillDownData[staffKey]!.take(10).map((att) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: Colors.purple.shade400),
                                  const SizedBox(width: 8),
                                  Text(att['date']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                                  const Spacer(),
                                  Text('${att['checkIn'] ?? '?'} - ${att['checkOut'] ?? '?'}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                  const SizedBox(width: 8),
                                  Text('${(att['hoursWorked'] as num?)?.toStringAsFixed(1) ?? '0'}h',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                ],
                              ),
                            )).toList()
                          else
                            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                          if (_drillDownData.containsKey(staffKey) && _drillDownData[staffKey]!.length > 10)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('...and ${_drillDownData[staffKey]!.length - 10} more records', 
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _loadAttendanceForStaff(dynamic staffId, String key) async {
    if (_drillDownData.containsKey(key)) return;
    if (staffId == null) return;
    final attendance = await DatabaseHelper().getAttendanceForStaff(staffId is int ? staffId : int.tryParse(staffId.toString()) ?? 0, _startDate, _endDate);
    if (mounted) {
      setState(() {
        _drillDownData[key] = attendance;
      });
    }
  }

  Widget _buildHROvertimeReport() {
    double totalOT = 0;
    double totalOTPay = 0;
    
    for (var item in _reportData) {
      totalOT += (item['totalOT'] as num?)?.toDouble() ?? 0;
      totalOTPay += (item['otPay'] as num?)?.toDouble() ?? 0;
    }
    
    return Column(
      children: [
        _buildSummaryHeader([
          _SummaryItem(AppLocalizations.of(context)!.staffWithOt, _reportData.length.toString(), Icons.people, Colors.orange),
          _SummaryItem(AppLocalizations.of(context)!.totalOt, '${totalOT.toStringAsFixed(1)}h', Icons.more_time, Colors.blue),
          _SummaryItem(AppLocalizations.of(context)!.otPay, '₹${totalOTPay.toStringAsFixed(0)}', Icons.payments, Colors.green),
        ]),
        Expanded(
          child: _reportData.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noOvertime))
              : ListView.builder(
                  itemCount: _reportData.length,
                  itemBuilder: (context, index) {
                    final item = _reportData[index];
                    final name = item['name'] ?? 'Unknown';
                    final ot = (item['totalOT'] as num?)?.toDouble() ?? 0;
                    final otPay = (item['otPay'] as num?)?.toDouble() ?? 0;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${ot.toStringAsFixed(1)} hours overtime'),
                        trailing: Text('₹${otPay.toStringAsFixed(0)}', 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ============== HELPER WIDGETS ==============
  
  Widget _buildSummaryHeader(List<_SummaryItem> items) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getCategoryColor(_selectedCategory).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) => Column(
          children: [
            Icon(item.icon, color: item.color, size: 24),
            const SizedBox(height: 4),
            Text(item.value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: item.color)),
            Text(item.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildPieListReport({
    required List<Map<String, dynamic>> data,
    required String labelKey,
    required String valueKey,
    required String secondaryKey,
    Map<String, Color>? colors,
  }) {
    // Calculate total for percentage
    int total = 0;
    for (var item in data) {
      total += (item[valueKey] as num?)?.toInt() ?? 0;
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        final label = item[labelKey]?.toString() ?? 'Unknown';
        final value = (item[valueKey] as num?)?.toInt() ?? 0;
        final secondary = (item[secondaryKey] as num?)?.toDouble() ?? 0;
        final percentage = total > 0 ? (value / total * 100) : 0;
        
        final color = colors?[label] ?? Colors.primaries[index % Colors.primaries.length];
        
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Text('${percentage.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
            title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${secondary.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.green)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  
  _SummaryItem(this.label, this.value, this.icon, this.color);
}
