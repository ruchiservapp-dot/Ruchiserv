import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/database_helper.dart';

class UtensilReportScreen extends StatefulWidget {
  const UtensilReportScreen({super.key});

  @override
  State<UtensilReportScreen> createState() => _UtensilReportScreenState();
}

class _UtensilReportScreenState extends State<UtensilReportScreen> {
  String _filter = 'today'; // today, week, month, custom
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  
  List<Map<String, dynamic>> _dispatchedItems = [];
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final db = await DatabaseHelper().database;
    
    // Calculate date range based on filter
    DateTime start;
    DateTime end = DateTime.now();
    
    switch (_filter) {
      case 'today':
        start = DateTime(end.year, end.month, end.day);
        break;
      case 'week':
        start = end.subtract(const Duration(days: 7));
        break;
      case 'month':
        start = DateTime(end.year, end.month, 1);
        break;
      case 'custom':
        start = _startDate;
        end = _endDate;
        break;
      default:
        start = DateTime(end.year, end.month, end.day);
    }
    
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end.add(const Duration(days: 1)));
    
    // Get dispatched utensils with movement data
    final dispatched = await db.rawQuery('''
      SELECT 
        di.itemName,
        COUNT(*) as dispatchCount,
        SUM(di.loadedQty) as totalLoaded,
        SUM(COALESCE(di.returnedQty, 0)) as totalReturned,
        SUM(COALESCE(di.unloadedQty, 0)) as totalUnloaded,
        SUM(di.loadedQty - COALESCE(di.unloadedQty, di.returnedQty, 0)) as totalMissing
      FROM dispatch_items di
      JOIN dispatches d ON di.dispatchId = d.id
      WHERE di.itemType = 'UTENSIL'
        AND d.dispatchTime BETWEEN ? AND ?
      GROUP BY di.itemName
      ORDER BY totalLoaded DESC
    ''', [startStr, endStr]);
    
    // Get current inventory
    final inventory = await db.query('utensils', orderBy: 'name');
    
    setState(() {
      _dispatchedItems = dispatched;
      _inventory = inventory;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Utensil Report'),
          backgroundColor: Colors.teal,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Movement'),
              Tab(text: 'Inventory'),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (value) {
                if (value == 'custom') {
                  _showDatePicker();
                } else {
                  setState(() => _filter = value);
                  _loadData();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'today', child: Row(
                  children: [
                    Icon(_filter == 'today' ? Icons.check : null, size: 18),
                    const SizedBox(width: 8),
                    const Text('Today'),
                  ],
                )),
                PopupMenuItem(value: 'week', child: Row(
                  children: [
                    Icon(_filter == 'week' ? Icons.check : null, size: 18),
                    const SizedBox(width: 8),
                    const Text('Last 7 Days'),
                  ],
                )),
                PopupMenuItem(value: 'month', child: Row(
                  children: [
                    Icon(_filter == 'month' ? Icons.check : null, size: 18),
                    const SizedBox(width: 8),
                    const Text('This Month'),
                  ],
                )),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'custom', child: Row(
                  children: [
                    Icon(Icons.date_range, size: 18),
                    SizedBox(width: 8),
                    Text('Custom Range'),
                  ],
                )),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildMovementTab(),
                  _buildInventoryTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildMovementTab() {
    if (_dispatchedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No utensil movements in selected period',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    // Calculate totals
    int totalLoaded = 0;
    int totalReturned = 0;
    int totalMissing = 0;
    
    for (final item in _dispatchedItems) {
      totalLoaded += (item['totalLoaded'] as int?) ?? 0;
      totalReturned += (item['totalReturned'] as int?) ?? 0;
      totalMissing += (item['totalMissing'] as int?) ?? 0;
    }

    return Column(
      children: [
        // Summary cards
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.teal.shade50,
          child: Row(
            children: [
              _buildSummaryCard('Dispatched', totalLoaded, Colors.blue),
              _buildSummaryCard('Returned', totalReturned, Colors.green),
              _buildSummaryCard('Missing', totalMissing, Colors.red),
            ],
          ),
        ),
        // Filter label
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(_getFilterLabel(), style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
        // Items list
        Expanded(
          child: ListView.builder(
            itemCount: _dispatchedItems.length,
            itemBuilder: (context, index) {
              final item = _dispatchedItems[index];
              final loaded = (item['totalLoaded'] as int?) ?? 0;
              final returned = (item['totalUnloaded'] as int?) ?? (item['totalReturned'] as int?) ?? 0;
              final missing = loaded - returned;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: missing > 0 ? Colors.red.shade100 : Colors.green.shade100,
                    child: Icon(
                      Icons.restaurant,
                      color: missing > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(item['itemName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('Dispatched: $loaded | Returned: $returned'),
                  trailing: missing > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text('−$missing', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                        )
                      : Icon(Icons.check_circle, color: Colors.green.shade400),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryTab() {
    if (_inventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No utensils in inventory', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _inventory.length,
      itemBuilder: (context, index) {
        final item = _inventory[index];
        final total = (item['totalStock'] as int?) ?? 0;
        final available = (item['availableStock'] as int?) ?? 0;
        final issued = total - available;
        final percent = total > 0 ? (issued / total * 100).toStringAsFixed(0) : '0';
        
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: Text('${index + 1}', style: TextStyle(color: Colors.teal.shade700)),
            ),
            title: Text(item['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Total: $total | Available: $available | Issued: $issued ($percent%)'),
            trailing: _buildStockIndicator(available, total),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStockIndicator(int available, int total) {
    if (total == 0) return const SizedBox();
    final ratio = available / total;
    Color color;
    if (ratio > 0.7) {
      color = Colors.green;
    } else if (ratio > 0.3) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
    return Container(
      width: 60,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: ratio,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  String _getFilterLabel() {
    switch (_filter) {
      case 'today':
        return 'Today (${DateFormat.MMMd().format(DateTime.now())})';
      case 'week':
        return 'Last 7 Days';
      case 'month':
        return 'This Month (${DateFormat.MMMM().format(DateTime.now())})';
      case 'custom':
        return '${DateFormat.MMMd().format(_startDate)} - ${DateFormat.MMMd().format(_endDate)}';
      default:
        return 'Today';
    }
  }

  Future<void> _showDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    
    if (picked != null) {
      setState(() {
        _filter = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }
}
