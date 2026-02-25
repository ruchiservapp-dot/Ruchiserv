import 'package:ruchiserv/repositories/operation_repository.dart';
import 'package:ruchiserv/core/app_logger.dart';
// MODULE: VEHICLE MASTER (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-07 | Features: Fleet Management, Vehicle Type, Driver Info, In-House/Outside Classification
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added
import 'package:provider/provider.dart';
import '../core/settings_provider.dart';
import '../db/database_helper.dart';

class VehicleMasterScreen extends StatefulWidget {
  const VehicleMasterScreen({super.key});

  @override
  State<VehicleMasterScreen> createState() => _VehicleMasterScreenState();
}

class _VehicleMasterScreenState extends State<VehicleMasterScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;
  String? _firmId; // Added for correct syncing

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final settings = context.read<SettingsProvider>();
    _firmId = settings.firmId;

    final db = await DatabaseHelper().database;
    final result = await db.query('vehicles',
        orderBy:
            'vehicleNumber ASC'); // Ideally filter by firmId too if multi-tenant locally
    setState(() {
      _vehicles = result;
      _isLoading = false;
    });
  }

  Future<void> _addOrEditVehicle([Map<String, dynamic>? vehicle]) async {
    final isEdit = vehicle != null;
    final vehicleNumberController =
        TextEditingController(text: vehicle?['vehicleNumber'] ?? '');
    final vehicleTypeController =
        TextEditingController(text: vehicle?['vehicleType'] ?? '');
    final driverNameController =
        TextEditingController(text: vehicle?['driverName'] ?? '');
    final driverMobileController =
        TextEditingController(text: vehicle?['driverMobile'] ?? '');
    String type = vehicle?['type'] ?? 'INHOUSE';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Vehicle' : 'Add Vehicle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vehicleNumberController,
                decoration:
                    const InputDecoration(labelText: 'Vehicle Number *'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vehicleTypeController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  hintText: 'e.g., Tempo, Van, Truck, Auto',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Ownership'),
                items: const [
                  DropdownMenuItem(value: 'INHOUSE', child: Text('In-House')),
                  DropdownMenuItem(
                      value: 'OUTSIDE', child: Text('Outside Transporter')),
                ],
                onChanged: (v) => type = v ?? 'INHOUSE',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: driverNameController,
                decoration: const InputDecoration(labelText: 'Driver Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: driverMobileController,
                decoration: const InputDecoration(labelText: 'Driver Mobile'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (vehicleNumberController.text.isEmpty) return;
              final db = await DatabaseHelper().database;
              final now = DateTime.now().toIso8601String();
              final vehicleNum =
                  vehicleNumberController.text.trim().toUpperCase();

              try {
                // Check columns to handle legacy schemas (v11 vs AppSchema)
                final tableInfo =
                    await db.rawQuery('PRAGMA table_info(vehicles)');
                final columns =
                    tableInfo.map((row) => row['name'] as String).toSet();

                final Map<String, dynamic> data = {
                  'vehicleNumber': vehicleNum,
                  'vehicleType': vehicleTypeController.text.trim(),
                  'type': type,
                  'driverName': driverNameController.text.trim(),
                  'driverMobile': driverMobileController.text.trim(),
                  'firmId': _firmId ?? 'DEFAULT',
                  'updatedAt': now,
                };

                // Backward compatibility: Only add vehicleNo if column exists
                if (columns.contains('vehicleNo')) {
                  data['vehicleNo'] = vehicleNum;
                }

                // Check for missing AppSchema columns (in case sync hasn't run or failed)
                if (columns.contains('isActive')) {
                  data['isActive'] = 1;
                }

                if (isEdit) {
                  await OperationRepository()
                      .updateVehicle(vehicle['id'] as int, data);
                } else {
                  data['createdAt'] = now;
                  await OperationRepository().insertVehicle(data);
                }

                // AUTO-WHITELIST: Allow instant login for Driver
                if (driverMobileController.text.trim().isNotEmpty) {
                  await DatabaseHelper().insertAuthorizedMobile({
                    'firmId': data['firmId'],
                    'mobile': driverMobileController.text.trim(),
                    'role': 'Driver',
                    'name': driverNameController.text.trim(),
                    'addedBy': 'ADMIN_APP',
                  });
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  _loadVehicles();
                }
              } catch (e) {
                AppLogger.info("📍 Error saving vehicle: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving vehicle: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );

    vehicleNumberController.dispose();
    vehicleTypeController.dispose();
    driverNameController.dispose();
    driverMobileController.dispose();
  }

  Future<void> _deleteVehicle(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vehicle?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await OperationRepository().deleteVehicle(id);
      _loadVehicles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (settings.firmId != _firmId) {
      _firmId = settings.firmId;
      Future.microtask(() => _loadVehicles());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Master'),
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addOrEditVehicle()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No vehicles added yet'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _addOrEditVehicle(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Vehicle'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vehicles.length,
                  itemBuilder: (ctx, i) {
                    final v = _vehicles[i];
                    final isInhouse = v['type'] == 'INHOUSE';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isInhouse
                              ? Colors.blue.shade100
                              : Colors.orange.shade100,
                          child: Icon(
                            isInhouse
                                ? Icons.local_shipping
                                : Icons.call_received,
                            color: isInhouse ? Colors.blue : Colors.orange,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(v['vehicleNumber'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            if ((v['vehicleType'] ?? '').toString().isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(v['vehicleType'],
                                    style: const TextStyle(fontSize: 11)),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                isInhouse ? 'In-House' : 'Outside Transporter'),
                            if ((v['driverName'] ?? '').toString().isNotEmpty)
                              Text(
                                  'Driver: ${v['driverName']} | ${v['driverMobile']}'),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'edit') _addOrEditVehicle(v);
                            if (action == 'delete') _deleteVehicle(v['id']);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditVehicle(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
