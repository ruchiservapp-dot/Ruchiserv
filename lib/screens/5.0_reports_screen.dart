// MODULE: REPORTS SCREEN - COMPREHENSIVE
// Last Updated: 2025-12-08 | Features: Orders, Kitchen, Dispatch, HR Reports
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '3.3.2_staff_payroll_screen.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

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

  // Sub-report options per category
  final Map<String, List<String>> _subReports = {
    'Orders': ['Summary', 'By Food Type', 'By Meal Type', 'By Time Slot', 'Top Locations'],
    'Kitchen': ['Production', 'Top Dishes', 'By Category'],
    'Dispatch': ['Delivery Status', 'Capacity'],
    'HR': ['Attendance', 'Overtime'],
  };

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  String get _startDate {
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

  String get _endDate => DateFormat('yyyy-MM-dd').format(DateTime.now());

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
    });
    _loadReportData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
                        AppLocalizations.of(context)!.year
                      ]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedTimeline = val);
                          _loadReportData();
                        }
                      },
                    ),
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
                const Divider(height: 16),
                
                // Category Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Orders', 'Kitchen', 'Dispatch', 'HR'].map((cat) {
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
      default: return Icons.analytics;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Orders': return Colors.blue;
      case 'Kitchen': return Colors.orange;
      case 'Dispatch': return Colors.green;
      case 'HR': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Widget _buildReportContent() {
    switch (_selectedCategory) {
      case 'Orders': return _buildOrdersReport();
      case 'Kitchen': return _buildKitchenReport();
      case 'Dispatch': return _buildDispatchReport();
      case 'HR': return _buildHRReport();
      default: return const SizedBox();
    }
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(AppLocalizations.of(context)!.totalPax(totalPax), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${AppLocalizations.of(context)!.revenue}: ₹${totalRevenue.toStringAsFixed(0)}', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
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
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(DateFormat('dd').format(DateTime.parse(date)),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(DateFormat('EEE, MMM d').format(DateTime.parse(date))),
                  subtitle: Text('$orders orders | $pax pax | $completed completed'),
                  trailing: Text('₹${revenue.toStringAsFixed(0)}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFoodTypeReport() {
    return _buildPieListReport(
      data: _reportData,
      labelKey: 'foodType',
      valueKey: 'orderCount',
      secondaryKey: 'revenue',
      colors: {'Veg': Colors.green, 'Non-Veg': Colors.red, 'Both': Colors.orange},
    );
  }

  Widget _buildMealTypeReport() {
    return _buildPieListReport(
      data: _reportData,
      labelKey: 'mealType',
      valueKey: 'orderCount',
      secondaryKey: 'revenue',
      colors: {
        'Breakfast': Colors.amber,
        'Lunch': Colors.orange,
        'Dinner': Colors.purple,
        'Snacks': Colors.teal,
      },
    );
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
    
    return Column(
      children: [
        _buildSummaryHeader([
          _SummaryItem('Total Dishes', totalDishes.toString(), Icons.restaurant, Colors.blue),
          _SummaryItem(AppLocalizations.of(context)!.completed, completed.toString(), Icons.check_circle, Colors.green),
          _SummaryItem(AppLocalizations.of(context)!.inProgress, inProgress.toString(), Icons.pending, Colors.orange),
          _SummaryItem(AppLocalizations.of(context)!.pending, pending.toString(), Icons.schedule, Colors.grey),
        ]),
        Expanded(
          child: ListView.builder(
            itemCount: _reportData.length,
            itemBuilder: (context, index) {
              final item = _reportData[index];
              final date = item['date'] ?? '';
              final total = (item['totalDishes'] as num?)?.toInt() ?? 0;
              final done = (item['completed'] as num?)?.toInt() ?? 0;
              final pax = (item['totalPax'] as num?)?.toInt() ?? 0;
              
              final progress = total > 0 ? done / total : 0.0;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
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
                  trailing: Icon(
                    progress == 1 ? Icons.check_circle : Icons.pending,
                    color: progress == 1 ? Colors.green : Colors.orange,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
        
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$category | $orders orders | $pax pax'),
            trailing: Text('₹${revenue.toStringAsFixed(0)}', 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ),
        );
      },
    );
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
    int totalDispatches = 0, delivered = 0, inTransit = 0, pendingD = 0;
    
    for (var item in _reportData) {
      totalDispatches += (item['totalDispatches'] as num?)?.toInt() ?? 0;
      delivered += (item['delivered'] as num?)?.toInt() ?? 0;
      inTransit += (item['inTransit'] as num?)?.toInt() ?? 0;
      pendingD += (item['pending'] as num?)?.toInt() ?? 0;
    }
    
    return Column(
      children: [
        _buildSummaryHeader([
          _SummaryItem(AppLocalizations.of(context)!.totalDispatches, totalDispatches.toString(), Icons.local_shipping, Colors.blue),
          _SummaryItem(AppLocalizations.of(context)!.delivered, delivered.toString(), Icons.check_circle, Colors.green),
          _SummaryItem(AppLocalizations.of(context)!.inTransit, inTransit.toString(), Icons.directions_car, Colors.orange),
          _SummaryItem(AppLocalizations.of(context)!.pending, pendingD.toString(), Icons.pending, Colors.grey),
        ]),
        Expanded(
          child: ListView.builder(
            itemCount: _reportData.length,
            itemBuilder: (context, index) {
              final item = _reportData[index];
              final date = item['date'] ?? '';
              final total = (item['totalDispatches'] as num?)?.toInt() ?? 0;
              final done = (item['delivered'] as num?)?.toInt() ?? 0;
              final orders = (item['ordersCount'] as num?)?.toInt() ?? 0;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.local_shipping, color: Colors.white),
                  ),
                  title: Text(DateFormat('EEE, MMM d').format(DateTime.parse(date))),
                  subtitle: Text('$total dispatches | $orders orders'),
                  trailing: Chip(
                    label: Text('$done delivered'),
                    backgroundColor: Colors.green.withOpacity(0.2),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
              final name = item['name'] ?? 'Unknown';
              final days = (item['daysPresent'] as num?)?.toInt() ?? 0;
              final hours = (item['totalHours'] as num?)?.toDouble() ?? 0;
              final ot = (item['totalOvertime'] as num?)?.toDouble() ?? 0;
              final geoCompliant = (item['geoFenceCompliant'] as num?)?.toInt() ?? 0;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple,
                    child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$days days | ${hours.toStringAsFixed(1)}h${ot > 0 ? ' (+${ot.toStringAsFixed(1)} OT)' : ''}'),
                  trailing: geoCompliant > 0
                      ? Icon(Icons.location_on, color: geoCompliant == days ? Colors.green : Colors.orange)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
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
