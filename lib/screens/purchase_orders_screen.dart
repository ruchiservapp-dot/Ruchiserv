// MODULE: PURCHASE ORDERS SCREEN
// Last Updated: 2025-12-09 | Features: PO list, status tracking, details view
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/finance_repository.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  List<Map<String, dynamic>> _pos = [];
  bool _isLoading = true;
  String? _firmId;
  String? _statusFilter;

  final List<String> _statuses = ['All', 'SENT', 'VIEWED', 'ACCEPTED', 'DISPATCHED', 'DELIVERED'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final sp = await SharedPreferences.getInstance();
    _firmId = sp.getString('last_firm');
    
    if (_firmId != null) {
      _pos = await FinanceRepository().getPurchaseOrders(
        _firmId!, 
        status: _statusFilter == 'All' ? null : _statusFilter,
      );
    }
    
    setState(() => _isLoading = false);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SENT': return Colors.blue;
      case 'VIEWED': return Colors.orange;
      case 'ACCEPTED': return Colors.green;
      case 'DISPATCHED': return Colors.purple;
      case 'DELIVERED': return Colors.teal;
      default: return Colors.grey;
    }
  }

  Future<void> _viewPoDetails(Map<String, dynamic> po) async {
    final items = await FinanceRepository().getPoItems(po['id'] as int);
    
    showModalBottomSheet(

      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(po['status'] ?? 'SENT'),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(po['poNumber'] ?? 'PO', 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(po['status'] ?? 'SENT',
                      style: TextStyle(color: _getStatusColor(po['status'] ?? 'SENT'), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(po['vendorName'] ?? AppLocalizations.of(context).unknown, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 8),
                      Text(po['sentAt'] != null 
                        ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(po['sentAt']))
                        : AppLocalizations.of(context).unknown),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context).itemsCount(po['totalItems'] ?? 0), style: TextStyle(color: Colors.grey.shade600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${((po['totalAmount'] as num?) ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final rate = (item['rate'] as num?)?.toDouble() ?? 0;
                  final amount = (item['amount'] as num?)?.toDouble() ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(item['itemName'] ?? AppLocalizations.of(context).unknown),
                    subtitle: Text(
                      '${item['quantity']} ${item['unit'] ?? 'kg'} × ₹${rate.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    trailing: Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).purchaseOrdersTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Status Filter
          Container(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuses.map((status) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(status == 'All' ? AppLocalizations.of(context).catAll : status), // Assuming 'All' matches catAll
                    selected: _statusFilter == status || (status == 'All' && _statusFilter == null),
                    onSelected: (v) {
                      setState(() => _statusFilter = status == 'All' ? null : status);
                      _loadData();
                    },
                    selectedColor: _getStatusColor(status).withValues(alpha: 0.3),
                  ),
                )).toList(),
              ),
            ),
          ),
          
          // Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(AppLocalizations.of(context).purchaseOrdersCount(_pos.length), style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          
          // PO List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context).noPurchaseOrders),
                            const SizedBox(height: 8),
                            Text(AppLocalizations.of(context).runMrpHint, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _pos.length,
                        itemBuilder: (context, index) {
                          final po = _pos[index];
                          return GestureDetector(
                            onTap: () => _viewPoDetails(po),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top section (Header)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(po['status'] ?? 'SENT').withValues(alpha: 0.05),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(po['poNumber'] ?? 'PO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(height: 2),
                                            Text(
                                              po['sentAt'] != null ? DateFormat('MMM d, yyyy').format(DateTime.parse(po['sentAt'])) : '',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                        // Status Stamp
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(po['status'] ?? 'SENT').withValues(alpha: 0.1),
                                            border: Border.all(color: _getStatusColor(po['status'] ?? 'SENT').withValues(alpha: 0.5)),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            (po['status'] ?? 'SENT').toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1,
                                              color: _getStatusColor(po['status'] ?? 'SENT'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Dashed Line
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Flex(
                                          direction: Axis.horizontal,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: List.generate(
                                            (constraints.constrainWidth() / 10).floor(),
                                            (index) => SizedBox(width: 5, height: 1, child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey.shade300))),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Bottom section (Details)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.storefront, size: 14, color: Colors.grey.shade600),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                    po['vendorName'] ?? AppLocalizations.of(context).unknown,
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(AppLocalizations.of(context).itemsCount(po['totalItems'] ?? 0), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '₹${((po['totalAmount'] as num?) ?? 0).toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
