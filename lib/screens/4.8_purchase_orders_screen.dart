// MODULE: PURCHASE ORDERS SCREEN
// Last Updated: 2025-12-09 | Features: PO list, status tracking, details view
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
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
      _pos = await DatabaseHelper().getPurchaseOrders(
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
    final items = await DatabaseHelper().getPoItems(po['id']);
    
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
                      Text(po['vendorName'] ?? AppLocalizations.of(context)!.unknown, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 8),
                      Text(po['sentAt'] != null 
                        ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(po['sentAt']))
                        : AppLocalizations.of(context)!.unknown),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.itemsCount(po['totalItems'] ?? 0), style: TextStyle(color: Colors.grey.shade600)),
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
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(item['itemName'] ?? AppLocalizations.of(context)!.unknown),
                    trailing: Text(
                      '${item['quantity']} ${item['unit'] ?? 'kg'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
        title: Text(AppLocalizations.of(context)!.purchaseOrdersTitle),
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
                    label: Text(status == 'All' ? AppLocalizations.of(context)!.catAll : status), // Assuming 'All' matches catAll
                    selected: _statusFilter == status || (status == 'All' && _statusFilter == null),
                    onSelected: (v) {
                      setState(() => _statusFilter = status == 'All' ? null : status);
                      _loadData();
                    },
                    selectedColor: _getStatusColor(status).withOpacity(0.3),
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
                Text(AppLocalizations.of(context)!.purchaseOrdersCount(_pos.length), style: TextStyle(color: Colors.grey.shade600)),
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
                            Text(AppLocalizations.of(context)!.noPurchaseOrders),
                            const SizedBox(height: 8),
                            Text(AppLocalizations.of(context)!.runMrpHint, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _pos.length,
                        itemBuilder: (context, index) {
                          final po = _pos[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(po['status'] ?? 'SENT').withOpacity(0.2),
                                child: Icon(Icons.receipt, color: _getStatusColor(po['status'] ?? 'SENT')),
                              ),
                              title: Text(po['poNumber'] ?? 'PO',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(po['vendorName'] ?? AppLocalizations.of(context)!.unknown),
                                  Text(AppLocalizations.of(context)!.itemsCount(po['totalItems'] ?? 0),
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(po['status'] ?? 'SENT').withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(po['status'] ?? 'SENT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _getStatusColor(po['status'] ?? 'SENT'),
                                        fontWeight: FontWeight.bold,
                                      )),
                                  ),
                                  if (po['sentAt'] != null)
                                    Text(
                                      DateFormat('MMM d').format(DateTime.parse(po['sentAt'])),
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                ],
                              ),
                              onTap: () => _viewPoDetails(po),
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
