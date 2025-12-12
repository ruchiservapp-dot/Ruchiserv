// MODULE: ORDER MANAGEMENT (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '2.1_add_order_screen.dart';
import '2.3_summary_screen.dart';

class OrdersListScreen extends StatefulWidget {
  final DateTime date;
  const OrdersListScreen({super.key, required this.date});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final dateStr = widget.date.toIso8601String().split('T')[0];
      final data = await DatabaseHelper().getOrdersByDate(dateStr);
      setState(() {
        _orders = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.failedLoadOrders(e.toString());
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingOrders(e.toString())), backgroundColor: Colors.red),
      );
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByMealType(List<Map<String, dynamic>> orders) {
    final grouped = {
      'Breakfast': <Map<String, dynamic>>[],
      'Lunch': <Map<String, dynamic>>[],
      'Dinner': <Map<String, dynamic>>[],
      'Snacks/Others': <Map<String, dynamic>>[],
    };
    for (var order in orders) {
      final meal = (order['mealType'] ?? 'Snacks/Others') as String;
      (grouped[meal] ?? grouped['Snacks/Others'])!.add(order);
    }
    return grouped;
  }

  Map<String, int> _calculateTotals() {
    int veg = 0, nonVeg = 0;
    for (var order in _orders) {
      final paxVal = order['totalPax'] ?? order['pax'] ?? 0;
      final pax = paxVal is int ? paxVal : int.tryParse('$paxVal') ?? 0;
      final foodType = (order['foodType'] ?? '') as String;
      if (foodType == 'Veg') {
        veg += pax;
      } else {
        nonVeg += pax;
      }
    }
    return {'veg': veg, 'nonVeg': nonVeg, 'total': veg + nonVeg};
  }

  bool get _isPastDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pageDate = DateTime(widget.date.year, widget.date.month, widget.date.day);
    return pageDate.isBefore(today);
  }

  Future<void> _editOrder(Map<String, dynamic> order) async {
    if (_isPastDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.cannotEditPastOrders)),
      );
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddOrderScreen(date: widget.date, existingOrder: order),
      ),
    );
    if (result == true) await _loadOrders();
  }

  Future<void> _deleteOrder(int orderId) async {
    if (_isPastDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.cannotDeletePastOrders)),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteOrderTitle),
        content: Text(AppLocalizations.of(context)!.deleteOrderConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppLocalizations.of(context)!.delete)),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await DatabaseHelper().deleteOrder(orderId);
      await DatabaseHelper().queuePendingSync(
        table: 'orders',
        data: {"id": orderId},
        action: 'DELETE',
      );
      await _loadOrders();
      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.orderDeleted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorDeletingOrder(e.toString())), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildMealSection(String mealType, List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.blue.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(mealType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
              Text(AppLocalizations.of(context)!.ordersCount(orders.length), style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
            ],
          ),
        ),
        ...orders.map((order) {
          final orderId = order['id'] as int?;
          final isVeg = order['foodType'] == 'Veg';
          final pax = order['totalPax'] ?? order['pax'] ?? 0;
          final amount = order['finalAmount'] ?? 0;
          return Card(
            elevation: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isVeg ? Colors.green.shade600 : Colors.red.shade600,
                child: Icon(isVeg ? Icons.eco : Icons.restaurant, color: Colors.white),
              ),
              title: Text(order['customerName']?.toString() ?? AppLocalizations.of(context)!.unnamed, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order['location'] ?? AppLocalizations.of(context)!.noLocation} • ${order['mobile'] ?? ''}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Pax: $pax | ${order['mealType'] ?? ''} | ${order['foodType'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if ((order['discountPercent'] ?? 0) > 0)
                    Text('-${order['discountPercent']}%',
                        style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                ],
              ),
              onTap: _isPastDate ? null : () => _editOrder(order),
              onLongPress: (_isPastDate || orderId == null) ? null : () => _deleteOrder(orderId),
              tileColor: _isPastDate ? Colors.grey.shade50 : null, // Visual cue for disabled
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = '${widget.date.day}/${widget.date.month}/${widget.date.year}';
    final grouped = _groupByMealType(_orders);
    final totals = _calculateTotals();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.ordersDateTitle(formattedDate)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.summarize),
              tooltip: AppLocalizations.of(context)!.dishSummary,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryScreen(date: widget.date)));
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(_errorMessage!),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadOrders,
                          icon: const Icon(Icons.refresh),
                          label: Text(AppLocalizations.of(context)!.retry),
                        ),
                      ],
                    ),
                  )
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context)!.noOrdersFound, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView(
                          children: [
                            _buildMealSection('Breakfast', grouped['Breakfast']!),
                            _buildMealSection('Lunch', grouped['Lunch']!),
                            _buildMealSection('Dinner', grouped['Dinner']!),
                            _buildMealSection('Snacks/Others', grouped['Snacks/Others']!),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
        bottomNavigationBar: _orders.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                color: Colors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context)!.vegCount(totals['veg']!), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(AppLocalizations.of(context)!.nonVegCount(totals['nonVeg']!), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(AppLocalizations.of(context)!.totalCount(totals['total']!), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            : null,
        floatingActionButton: _isPastDate
            ? null // Hide add button for past dates
            : FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context)!.addOrder),
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => AddOrderScreen(date: widget.date)),
                  );
                  if (result == true) await _loadOrders();
                },
              ),
      ),
    );
  }
}
