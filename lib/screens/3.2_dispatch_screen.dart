// MODULE: OPERATIONS DISPATCH VIEW (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-07 | Features: Legacy Dispatch View from Operations
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  List<Map<String, dynamic>> _pendingDispatches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDispatches();
  }

  Future<void> _loadDispatches() async {
    setState(() => _isLoading = true);
    final dispatches = await DatabaseHelper().getPendingDispatches();
    setState(() {
      _pendingDispatches = dispatches;
      _isLoading = false;
    });
  }

  Future<void> _showAddDispatchDialog() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final orders = await DatabaseHelper().getOrdersWithoutDispatch(dateStr);

    if (!mounted) return;

    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noOrdersForDispatch)),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.createDispatch),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return ListTile(
                  title: Text(order['customerName']),
                  subtitle: Text("${order['time']} - ${order['location']}"),
                  onTap: () {
                    Navigator.pop(context);
                    _createDispatch(order['id']);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _createDispatch(int orderId) async {
    final driverController = TextEditingController();
    final vehicleController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.dispatchDetails),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: driverController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.driverName),
              ),
              TextField(
                controller: vehicleController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.vehicleNumber),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                await DatabaseHelper().insertDispatch({
                  'orderId': orderId,
                  'dispatchTime': DateTime.now().toIso8601String(),
                  'status': 'Pending',
                  'driverName': driverController.text,
                  'vehicleNumber': vehicleController.text,
                });
                if (mounted) Navigator.pop(context);
                _loadDispatches();
                if (mounted) Navigator.pop(context);
                _loadDispatches();
              },
              child: Text(AppLocalizations.of(context)!.createDispatch),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.dispatchView)),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDispatchDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingDispatches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping_outlined,
                          size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.noPendingDispatches,
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.tapToAddDispatch,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddDispatchDialog,
                        icon: const Icon(Icons.add),
                        label: Text(AppLocalizations.of(context)!.createDispatch),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _pendingDispatches.length,
                  itemBuilder: (context, index) {
                    final dispatch = _pendingDispatches[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(AppLocalizations.of(context)!.orderFor(dispatch['customerName'])),
                        subtitle: Text(
                            "${AppLocalizations.of(context)!.locLabel(dispatch['location'] ?? '')}\n${AppLocalizations.of(context)!.driverWithVehicle(dispatch['driverName'], dispatch['vehicleNumber'])}"),
                        trailing: DropdownButton<String>(
                          value: dispatch['status'],
                          items: [AppLocalizations.of(context)!.statusPending, AppLocalizations.of(context)!.statusDispatched, AppLocalizations.of(context)!.statusDelivered]
                              .map((s) => DropdownMenuItem(value: s == AppLocalizations.of(context)!.statusPending ? 'Pending' : (s == AppLocalizations.of(context)!.statusDispatched ? 'Dispatched' : 'Delivered'), child: Text(s)))
                              // Wait, the value must match DB value 'Pending', 'Dispatched'. The display text should be localized.
                              // So value: 'Pending', child: Text(AppLocalizations.of(context)!.statusPending)
                              // Let's rewrite this logic clearly.
                              .toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              try {
                                final db = await DatabaseHelper().database;
                                final updates = <String, dynamic>{'status': val};
                                if (val == 'Delivered') {
                                  updates['deliveryTime'] =
                                      DateTime.now().toIso8601String();
                                }
                                await db.update('dispatch', updates,
                                    where: 'id = ?', whereArgs: [dispatch['id']]);
                                _loadDispatches();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text(AppLocalizations.of(context)!.failedUpdateStatus(e.toString()))),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
