// MODULE: ORDER FULL SCREEN VIEW (MRP Locked Orders)
// Displays locked order in full screen with admin edit capability
import 'package:flutter/material.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '../db/database_helper.dart';
import '../services/biometric_service.dart';
import '../services/permission_service.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderFullScreenViewScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final DateTime date;

  const OrderFullScreenViewScreen({
    super.key,
    required this.order,
    required this.date,
  });

  @override
  State<OrderFullScreenViewScreen> createState() => _OrderFullScreenViewScreenState();
}

class _OrderFullScreenViewScreenState extends State<OrderFullScreenViewScreen> {
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isEditMode = false;
  bool _isSaving = false;
  
  // Order data
  late Map<String, dynamic> _orderData;
  List<Map<String, dynamic>> _dishes = [];
  List<Map<String, dynamic>> _purchaseOrders = [];
  
  // Controllers for editable fields
  final _customerController = TextEditingController();
  final _mobileController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _paxController = TextEditingController();
  
  String _mealType = 'Lunch';
  String _foodType = 'Veg';

  @override
  void initState() {
    super.initState();
    _orderData = Map<String, dynamic>.from(widget.order);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Check if user is admin
      _isAdmin = await PermissionService.instance.isAdmin();
      
      // Load dishes for this order
      final orderId = _orderData['id'] as int;
      _dishes = await DatabaseHelper().getDishesForOrder(orderId);
      
      // Load purchase orders for this order
      _purchaseOrders = await _loadPurchaseOrdersForOrder(orderId);
      
      // Populate controllers
      _customerController.text = _orderData['customerName']?.toString() ?? '';
      _mobileController.text = _orderData['mobile']?.toString() ?? '';
      _locationController.text = _orderData['location']?.toString() ?? '';
      _notesController.text = _orderData['notes']?.toString() ?? '';
      _paxController.text = (_orderData['totalPax'] ?? _orderData['pax'] ?? 0).toString();
      _mealType = _orderData['mealType']?.toString() ?? 'Lunch';
      _foodType = _orderData['foodType']?.toString() ?? 'Veg';
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadPurchaseOrdersForOrder(int orderId) async {
    final db = await DatabaseHelper().database;
    // Get all POs that include this order (via orderIds field)
    final allPOs = await db.query('purchase_orders');
    
    return allPOs.where((po) {
      final orderIds = po['orderIds']?.toString() ?? '';
      return orderIds.split(',').map((s) => s.trim()).contains(orderId.toString());
    }).toList();
  }

  Future<void> _attemptUnlock() async {
    // Try biometric first
    final bioService = BiometricService();
    final canUseBio = await bioService.canCheckBiometrics();
    
    bool authenticated = false;
    
    if (canUseBio) {
      authenticated = await bioService.authenticate();
    }
    
    // If biometric failed or unavailable, show password dialog
    if (!authenticated) {
      authenticated = await _showPasswordDialog();
    }
    
    if (authenticated) {
      setState(() => _isEditMode = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.editModeEnabled),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<bool> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_open, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.enterPassword),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.adminPasswordRequired),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.password,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.password),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              // Verify password against stored admin credentials
              final sp = await SharedPreferences.getInstance();
              final firmId = sp.getString('last_firm') ?? '';
              final mobile = sp.getString('last_mobile') ?? '';
              
              final db = await DatabaseHelper().database;
              final users = await db.query('users',
                where: 'firmId = ? AND mobile = ? AND role = ?',
                whereArgs: [firmId, mobile, 'Admin'],
                limit: 1,
              );
              
              if (users.isNotEmpty) {
                final storedPassword = users.first['passwordHash']?.toString() ?? '';
                if (passwordController.text == storedPassword) {
                  Navigator.pop(context, true);
                  return;
                }
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.incorrectPassword),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text(AppLocalizations.of(context)!.unlock),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  Future<void> _saveAndRerunMRP() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.rerunMRPTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.rerunMRPMessage),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ${AppLocalizations.of(context)!.cancelOldPOs}', 
                    style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('• ${AppLocalizations.of(context)!.notifySuppliers}', 
                    style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('• ${AppLocalizations.of(context)!.notifyCustomer}', 
                    style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('• ${AppLocalizations.of(context)!.generateNewPOs}', 
                    style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context)!.rerunMRP),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      final orderId = _orderData['id'] as int;
      final db = DatabaseHelper();

      // 1. Update order with new data
      await _updateOrder();

      // 2. Cancel old POs (soft delete)
      await db.cancelPOsForOrder(orderId);

      // 3. Send cancellation notifications to suppliers
      for (final po in _purchaseOrders) {
        if (po['status'] != 'CANCELLED') {
          await NotificationService.queuePOCancellationNotification(
            poId: po['id'] as int,
            supplierName: po['supplierName']?.toString() ?? '',
            supplierMobile: po['supplierMobile']?.toString() ?? '',
            orderId: orderId,
          );
        }
      }

      // 4. Send update notification to customer
      await NotificationService.queueOrderUpdateNotification(
        orderId: orderId,
        orderData: _orderData,
      );

      // 5. Reset order MRP status
      await db.resetOrderForMRP(orderId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.orderUpdatedRerunMRP),
          backgroundColor: Colors.green,
        ),
      );

      // Return true to indicate order was modified
      Navigator.pop(context, true);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateOrder() async {
    final orderId = _orderData['id'] as int;
    
    final updatedOrder = {
      'customerName': _customerController.text.trim(),
      'mobile': _mobileController.text.trim(),
      'location': _locationController.text.trim(),
      'notes': _notesController.text.trim(),
      'totalPax': int.tryParse(_paxController.text) ?? 0,
      'mealType': _mealType,
      'foodType': _foodType,
    };

    final db = await DatabaseHelper().database;
    await db.update('orders', updatedOrder, where: 'id = ?', whereArgs: [orderId]);
    
    // Update local copy
    _orderData.addAll(updatedOrder);
  }

  @override
  void dispose() {
    _customerController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _paxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${widget.date.day}/${widget.date.month}/${widget.date.year}';
    final mrpStatus = _orderData['mrpStatus']?.toString() ?? '';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.orderDetails),
        centerTitle: true,
        actions: [
          // Admin Edit Button (locked)
          if (_isAdmin && !_isEditMode)
            IconButton(
              icon: const Icon(Icons.lock),
              tooltip: AppLocalizations.of(context)!.unlockToEdit,
              onPressed: _attemptUnlock,
            ),
          // Unlocked indicator
          if (_isAdmin && _isEditMode)
            IconButton(
              icon: const Icon(Icons.lock_open, color: Colors.green),
              tooltip: AppLocalizations.of(context)!.editModeActive,
              onPressed: null,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  _buildStatusBanner(mrpStatus),
                  const SizedBox(height: 16),

                  // Order Info Card
                  _buildOrderInfoCard(dateStr),
                  const SizedBox(height: 16),

                  // Dishes Section
                  _buildDishesSection(),
                  const SizedBox(height: 16),

                  // Purchase Orders Section
                  _buildPurchaseOrdersSection(),
                  const SizedBox(height: 16),

                  // Pricing Summary
                  _buildPricingSummary(),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
      floatingActionButton: _isEditMode
          ? FloatingActionButton.extended(
              icon: _isSaving 
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(AppLocalizations.of(context)!.saveAndRerunMRP),
              backgroundColor: Colors.orange,
              onPressed: _isSaving ? null : _saveAndRerunMRP,
            )
          : null,
    );
  }

  Widget _buildStatusBanner(String mrpStatus) {
    final isLocked = _orderData['isLocked'] == 1 || mrpStatus.isNotEmpty && mrpStatus != 'PENDING';
    
    Color bgColor;
    Color borderColor;
    IconData icon;
    String statusText;

    if (mrpStatus == 'PO_SENT') {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
      icon = Icons.check_circle;
      statusText = AppLocalizations.of(context)!.poSentStatus;
    } else if (isLocked) {
      bgColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade300;
      icon = Icons.lock;
      statusText = AppLocalizations.of(context)!.mrpProcessedStatus;
    } else {
      bgColor = Colors.grey.shade100;
      borderColor = Colors.grey.shade300;
      icon = Icons.pending;
      statusText = AppLocalizations.of(context)!.pendingStatus;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: borderColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusText, style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: borderColor,
                )),
                if (_isEditMode)
                  Text(
                    AppLocalizations.of(context)!.editModeActiveMessage,
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(String dateStr) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.orderInformation,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            
            // Date & Pax Row
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    AppLocalizations.of(context)!.date,
                    dateStr,
                    Icons.calendar_today,
                  ),
                ),
                if (_isEditMode)
                  Expanded(
                    child: TextField(
                      controller: _paxController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Total Pax',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: _buildInfoItem(
                      'Total Pax',
                      _paxController.text,
                      Icons.people,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer Name
            if (_isEditMode)
              TextField(
                controller: _customerController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.customerName,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
              )
            else
              _buildInfoItem(
                AppLocalizations.of(context)!.customerName,
                _customerController.text,
                Icons.person,
              ),
            const SizedBox(height: 12),

            // Mobile & Location Row
            Row(
              children: [
                Expanded(
                  child: _isEditMode
                      ? TextField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.mobile,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.phone),
                          ),
                        )
                      : _buildInfoItem(
                          AppLocalizations.of(context)!.mobile,
                          _mobileController.text.isEmpty ? '-' : _mobileController.text,
                          Icons.phone,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isEditMode
                      ? TextField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.location,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.location_on),
                          ),
                        )
                      : _buildInfoItem(
                          AppLocalizations.of(context)!.location,
                          _locationController.text.isEmpty ? '-' : _locationController.text,
                          Icons.location_on,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Meal Type & Food Type
            Row(
              children: [
                Expanded(
                  child: _isEditMode
                      ? DropdownButtonFormField<String>(
                          value: _mealType,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.mealType,
                            border: const OutlineInputBorder(),
                          ),
                          items: ['Breakfast', 'Lunch', 'Dinner', 'Snacks/Others']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(() => _mealType = v ?? 'Lunch'),
                        )
                      : _buildInfoItem(
                          AppLocalizations.of(context)!.mealType,
                          _mealType,
                          Icons.restaurant_menu,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isEditMode
                      ? DropdownButtonFormField<String>(
                          value: _foodType,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.foodType,
                            border: const OutlineInputBorder(),
                          ),
                          items: ['Veg', 'Non-Veg']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(() => _foodType = v ?? 'Veg'),
                        )
                      : _buildInfoItem(
                          AppLocalizations.of(context)!.foodType,
                          _foodType,
                          _foodType == 'Veg' ? Icons.eco : Icons.restaurant,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildDishesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)!.dishes,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${_dishes.length} ${AppLocalizations.of(context)!.items}',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const Divider(),
            if (_dishes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text(AppLocalizations.of(context)!.noDishes)),
              )
            else
              ..._dishes.map((dish) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: dish['foodType'] == 'Veg' 
                          ? Colors.green.shade100 
                          : Colors.red.shade100,
                      child: Icon(
                        dish['foodType'] == 'Veg' ? Icons.eco : Icons.restaurant,
                        size: 16,
                        color: dish['foodType'] == 'Veg' ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(dish['name']?.toString() ?? '-'),
                    subtitle: Text('${dish['category'] ?? ''} • Qty: ${dish['pax'] ?? 0}'),
                    trailing: Text('₹${dish['cost'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseOrdersSection() {
    final activePOs = _purchaseOrders.where((po) => po['status'] != 'CANCELLED').toList();
    final cancelledPOs = _purchaseOrders.where((po) => po['status'] == 'CANCELLED').toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)!.purchaseOrders,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${activePOs.length} Active',
                          style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                    ),
                    const SizedBox(width: 4),
                    if (cancelledPOs.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${cancelledPOs.length} Cancelled',
                            style: TextStyle(fontSize: 11, color: Colors.red.shade700)),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(),
            
            // Active POs
            if (activePOs.isEmpty && cancelledPOs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text(AppLocalizations.of(context)!.noPurchaseOrders)),
              )
            else ...[
              ...activePOs.map((po) => _buildPOTile(po, false)),
              if (cancelledPOs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Cancelled POs', style: TextStyle(
                  fontSize: 12, 
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                )),
                ...cancelledPOs.map((po) => _buildPOTile(po, true)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPOTile(Map<String, dynamic> po, bool isCancelled) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isCancelled ? Colors.red.shade100 : Colors.blue.shade100,
        child: Icon(
          isCancelled ? Icons.cancel : Icons.receipt_long,
          size: 16,
          color: isCancelled ? Colors.red : Colors.blue,
        ),
      ),
      title: Text(
        po['supplierName']?.toString() ?? 'Unknown Supplier',
        style: TextStyle(
          decoration: isCancelled ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text('PO #${po['id']} • ${po['status'] ?? 'PENDING'}'),
      trailing: Text(
        '₹${po['totalAmount'] ?? 0}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isCancelled ? Colors.grey : Colors.black,
          decoration: isCancelled ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }

  Widget _buildPricingSummary() {
    final beforeDiscount = _orderData['beforeDiscount'] ?? 0;
    final discountPercent = _orderData['discountPercent'] ?? 0;
    final finalAmount = _orderData['finalAmount'] ?? 0;
    final serviceCost = _orderData['serviceCost'] ?? 0;
    final counterSetupCost = _orderData['counterSetupCost'] ?? 0;
    final grandTotal = _orderData['grandTotal'] ?? finalAmount;

    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.pricingSummary,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildPriceRow(AppLocalizations.of(context)!.subtotal, '₹$beforeDiscount'),
            if (discountPercent > 0)
              _buildPriceRow('Discount ($discountPercent%)', '-₹${(beforeDiscount * discountPercent / 100).toStringAsFixed(0)}'),
            _buildPriceRow(AppLocalizations.of(context)!.dishTotal, '₹$finalAmount'),
            if (serviceCost > 0)
              _buildPriceRow(AppLocalizations.of(context)!.serviceCost, '₹$serviceCost'),
            if (counterSetupCost > 0)
              _buildPriceRow(AppLocalizations.of(context)!.counterSetupCost, '₹$counterSetupCost'),
            const Divider(),
            _buildPriceRow(
              AppLocalizations.of(context)!.grandTotal,
              '₹$grandTotal',
              isBold: true,
              isLarge: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isLarge ? 16 : 14,
          )),
          Text(value, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isLarge ? 18 : 14,
            color: isLarge ? Colors.blueAccent : Colors.black,
          )),
        ],
      ),
    );
  }
}
