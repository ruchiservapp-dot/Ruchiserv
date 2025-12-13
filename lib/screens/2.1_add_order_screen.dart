// MODULE: ORDER MANAGEMENT (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// lib/screens/2.1_add_order_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import '../db/database_helper.dart';
import '../services/permission_service.dart';
import '../services/notification_service.dart';
import '../utils/staffing_logic.dart';
import '../services/language_service.dart';
import '../services/master_data_sync_service.dart';

class AddOrderScreen extends StatefulWidget {
  final DateTime date;
  final Map<String, dynamic>? existingOrder;

  const AddOrderScreen({
    super.key,
    required this.date,
    this.existingOrder,
  });

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  // Form
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _mobileController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  // Order core fields
  String _mealType = 'Lunch';
  String _foodType = 'Veg';
  int _pax = 0;
  TimeOfDay? _selectedTime;

  double _beforeDiscount = 0;
  double _discountPercent = 0;
  double _finalAmount = 0;

  // Service & Counter Setup
  bool _serviceRequired = false;
  String _serviceType = 'BUFFET';
  int _counterCount = 1;
  int _staffCount = 0;
  double _staffRate = 0;
  bool _counterSetupRequired = false;
  double _counterSetupRate = 0;
  double _serviceCost = 0;
  double _counterSetupCost = 0;
  double _grandTotal = 0;
  
  double get _discountAmount => _beforeDiscount * _discountPercent / 100;

  bool _isSaving = false;
  
  bool _isStaffInfoManual = false;
  late TextEditingController _staffCountController;
  
  // RBAC: Rate visibility
  bool _canViewRates = true;

  // Dishes: Map of Category -> List of Rows
  // Each row: {name, foodType, pax, rate, cost}
  final Map<String, List<Map<String, dynamic>>> _categorizedDishes = {};

  // Defined Categories in order
  static const List<String> _categories = [
    'Starters',
    'Main Course',
    'Desserts',
    'Beverages',
    'Specialties'
  ];

  // Dish suggestions from DB (per category)
  final Map<String, List<Map<String, dynamic>>> _dishSuggestions = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize empty lists for all categories
    for (var cat in _categories) {
      _categorizedDishes[cat] = [];
    }

    // If editing, hydrate fields
    final o = widget.existingOrder;
    if (o != null) {
      _customerController.text = o['customerName']?.toString() ?? '';
      _mobileController.text = o['mobile']?.toString() ?? '';
      _locationController.text = o['location']?.toString() ?? '';
      _mealType = o['mealType']?.toString() ?? 'Lunch';
      _foodType = o['foodType']?.toString() ?? 'Veg';
      _pax = _parseInt(o['totalPax']) ?? 0;
      _beforeDiscount = _parseDouble(o['beforeDiscount']) ?? 0;
      _discountPercent = _parseDouble(o['discountPercent']) ?? 0;
      _finalAmount = _parseDouble(o['finalAmount']) ?? 0;
      
      // Service fields hydration
      _serviceRequired = (o['serviceRequired'] == 1);
      _serviceType = o['serviceType']?.toString() ?? 'BUFFET';
      _counterCount = _parseInt(o['counterCount']) ?? 1;
      _staffCount = _parseInt(o['staffCount']) ?? 0;
      _staffRate = _parseDouble(o['staffRate']) ?? 0;
      _counterSetupRequired = (o['counterSetupRequired'] == 1);
      _counterSetupRate = _parseDouble(o['counterSetupRate']) ?? 0;
      _serviceCost = _parseDouble(o['serviceCost']) ?? 0;
      _counterSetupCost = _parseDouble(o['counterSetupCost']) ?? 0;
      _grandTotal = _parseDouble(o['grandTotal']) ?? 0;

      // Parse existing time if available
      final timeStr = o['time']?.toString();
      if (timeStr != null && timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            _selectedTime = TimeOfDay(hour: hour, minute: minute);
          }
        }
      }

      // Load existing dishes from database
      _loadExistingDishes(o['id'] as int);
    } else {
      // New order
      _ensureDefaultRows();
      _loadLastServiceRates();
    }
    
    // Load dish suggestions from database
    _loadDishSuggestions();
    
    // RBAC: Check if user can view rates
    _loadRateVisibility();
    
    _staffCountController = TextEditingController(text: _staffCount.toString());
  }

  Future<void> _loadLastServiceRates() async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'DEFAULT';
    
    if (firmId != 'DEFAULT') {
      final db = DatabaseHelper();
      final sRate = await db.getLastServiceRate(firmId, 'STAFF');
      final cRate = await db.getLastServiceRate(firmId, 'COUNTER');
      
      if (mounted) {
        setState(() {
          if (sRate > 0 && _staffRate == 0) _staffRate = sRate;
          if (cRate > 0 && _counterSetupRate == 0) _counterSetupRate = cRate;
          // Recalculate IF we have other data, but usually this is fresh setup
        });
      }
    }
  }
  
  Future<void> _loadRateVisibility() async {
    final canView = await PermissionService.instance.canViewRates();
    if (mounted) {
      setState(() => _canViewRates = canView);
    }
  }

  Future<void> _loadExistingDishes(int orderId) async {
    final dishes = await DatabaseHelper().getDishesForOrder(orderId);
    
    // Group dishes by category
    for (final dish in dishes) {
      final category = dish['category']?.toString() ?? 'Main Course';
      // Ensure category exists in our map
      if (!_categorizedDishes.containsKey(category)) {
        _categorizedDishes[category] = [];
      }
      _categorizedDishes[category]!.add({
        'name': dish['name'],
        'pax': dish['pax'] ?? 0,
        'rate': dish['rate'] ?? 0,
        'cost': dish['cost'] ?? 0,
        'foodType': dish['foodType'] ?? _foodType,
        '_localId': '${DateTime.now().microsecondsSinceEpoch}_${dish['id'] ?? 'new'}',
      });
    }
    
    // Ensure at least one row per category
    _ensureDefaultRows();
    _recalculateTotals();
  }

  Future<void> _loadDishSuggestions() async {
    for (var cat in _categories) {
      final suggestions = await DatabaseHelper().getDishSuggestions(cat);
      setState(() {
        _dishSuggestions[cat] = suggestions;
      });
    }
  }

  void _ensureDefaultRows() {
    for (var cat in _categories) {
      if (_categorizedDishes[cat]!.isEmpty) {
        _addDishRow(cat);
      }
    }
    setState(() {});
  }

  void _addDishRow(String category) {
    setState(() {
      _categorizedDishes[category]!.add({
        'name': null,
        'pax': _pax, // Auto-fill with total pax value
        'rate': 0,
        'cost': 0,
        'cost': 0,
        'foodType': _foodType,
        '_localId': '${DateTime.now().microsecondsSinceEpoch}',
      });
    });
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return double.tryParse(v.toString())?.toInt();
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  void _recalculateTotals() {
    double sum = 0;
    for (var cat in _categories) {
      for (final d in _categorizedDishes[cat]!) {
        // Only count if dish has both name and rate
        final name = d['name']?.toString().trim() ?? '';
        final rate = _parseDouble(d['rate']) ?? 0;
        if (name.isNotEmpty && rate > 0) {
          final qty = _parseInt(d['pax']) ?? 0;
          final cost = qty * rate;
          d['cost'] = cost;
          sum += cost;
        } else {
          d['cost'] = 0;
        }
      }
    }
    _beforeDiscount = sum;
    _finalAmount = sum - (sum * (_discountPercent / 100));
    _recalculateServiceCosts();
    setState(() {});
  }

  /// Calculate service and counter costs using StaffingLogic
  void _recalculateServiceCosts() {
    // Count total dishes with name and rate
    int dishCount = 0;
    for (var cat in _categories) {
      for (final d in _categorizedDishes[cat]!) {
        final name = d['name']?.toString().trim() ?? '';
        final rate = _parseInt(d['rate']) ?? 0;
        if (name.isNotEmpty && rate > 0) {
          dishCount++;
        }
      }
    }

    // Calculate staff count using StaffingLogic
    if (_serviceRequired && _pax > 0 && dishCount > 0) {
      if (!_isStaffInfoManual) {
        _staffCount = StaffingLogic.calculateServers(
          paxCount: _pax,
          serviceType: _serviceType,
          dishCount: dishCount,
          counterCount: _counterCount,
        );
        _staffCountController.text = _staffCount.toString();
      }
      _serviceCost = StaffingLogic.calculateServiceCost(
        staffCount: _staffCount,
        ratePerStaff: _staffRate,
      );
    } else {
      if (!_isStaffInfoManual) {
        _staffCount = 0;
        _staffCountController.text = '0';
      }
      _serviceCost = 0;
    }

    // Calculate counter setup cost
    if (_counterSetupRequired) {
      _counterSetupCost = StaffingLogic.calculateCounterSetupCost(
        counterCount: _counterCount,
        ratePerCounter: _counterSetupRate,
      );
    } else {
      _counterSetupCost = 0;
    }

    // Grand Total = Dish Total + Service Cost + Counter Setup Cost
    _grandTotal = _finalAmount + _serviceCost + _counterSetupCost;
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final dateStr = widget.date.toIso8601String().split('T').first;

      // Collect all valid dishes from all categories
      final List<Map<String, dynamic>> allValidDishes = [];
      for (var cat in _categories) {
        for (final d in _categorizedDishes[cat]!) {
          // Filter: Must have a name selected. Qty can be 0 if you want to just list it, but usually cost implies qty>0.
          // User said "rows can be kept blank", so we ignore those with null name.
          if (d['name'] != null) {
             // If you want to enforce qty > 0 for saved items:
             // if ((_parseInt(d['pax']) ?? 0) > 0) ...
             // For now, I'll allow saving 0 qty items if they have a name, or just filter them.
             // Usually 0 qty means "not ordered". Let's filter > 0 qty to be clean.
             if ((_parseInt(d['pax']) ?? 0) > 0) {
               allValidDishes.add({
                 ...d,
                 'category': cat, // Attach category here
               });
             }
          }
        }
      }

      // Get firmId from logged-in user
      final sp = await SharedPreferences.getInstance();
      final firmId = sp.getString('last_firm') ?? 'DEFAULT';

      // order map
      final order = <String, dynamic>{
        'firmId': firmId,
        'date': dateStr,
        'customerName': _customerController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'email': null,
        'location': _locationController.text.trim(),
        'mealType': _mealType,
        'foodType': _foodType,
        'time': _selectedTime != null
            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
            : null,
        'notes': _notesController.text.trim(),
        'beforeDiscount': _beforeDiscount,
        'discountPercent': _discountPercent,
        'discountAmount': (_beforeDiscount * _discountPercent / 100),
        'finalAmount': _finalAmount,
        'totalPax': _pax,
        'isLocked': 0,
        // Service & Counter Setup
        'serviceRequired': _serviceRequired ? 1 : 0,
        'serviceType': _serviceType,
        'counterCount': _counterCount,
        'staffCount': _staffCount,
        'staffRate': _staffRate,
        'counterSetupRequired': _counterSetupRequired ? 1 : 0,
        'counterSetupRate': _counterSetupRate,
        'serviceCost': _serviceCost,
        'counterSetupCost': _counterSetupCost,
        'grandTotal': _grandTotal,
      };

      // prepare dishes payload
      final dishRows = allValidDishes.map((d) => {
            'name': d['name'],
            'foodType': d['foodType'] ?? _foodType,
            'pax': _parseInt(d['pax']) ?? 0, // Pax is int
            'rate': d['rate'] ?? 0, // Maintain double precision
            'manualCost': 0,
            'cost': d['cost'] ?? 0, // Maintain double precision
            'category': d['category'],
          }).toList();

      if (widget.existingOrder != null) {
        await DatabaseHelper().updateOrder(
          widget.existingOrder!['id'] as int,
          order,
          dishRows,
        );
      } else {
        final id = await DatabaseHelper().insertOrder(order, dishRows);
        if (id == null || id <= 0) throw Exception('Insert failed');
        
        // Trigger Notification (Fire & Forget)
        NotificationService.queueOrderConfirmation(
          orderId: id,
          orderData: {...order, 'id': id, 'dishes': dishRows}, // Ensure ID is passed
        ).then((_) => print('🔔 Notification queued')).catchError((e) => print('🔕 Notification trigger failed: $e'));
      }

      // Save service rates for future use (Non-critical, wrap in try-catch)
      if (firmId != 'DEFAULT') {
        try {
          if (_staffRate > 0) await DatabaseHelper().upsertServiceRate(firmId, 'STAFF', _staffRate);
          if (_counterSetupRate > 0) await DatabaseHelper().upsertServiceRate(firmId, 'COUNTER', _counterSetupRate);
        } catch (_) {
          // Ignore service rate save errors to prevent blocking order completion
          print('Failed to save service rates: $_');
        }
      }

      // Save dishes to master table for future autocomplete (non-critical)
      try {
        for (final d in allValidDishes) {
          final name = d['name']?.toString() ?? '';
          final category = d['category']?.toString() ?? '';
          final rate = _parseInt(d['rate']) ?? 0; // Master expects int
          final foodType = d['foodType']?.toString() ?? 'Veg';
          if (name.isNotEmpty && category.isNotEmpty) {
            await DatabaseHelper().upsertDishMaster(
              name: name,
              category: category,
              rate: rate,
              foodType: foodType,
            );
          }
        }
      } catch (_) {
        // Silently ignore dish master save errors - main order is already saved
      }

      if (!mounted) return;
      
      // Trigger Master Data Sync (for any new dishes created)
      MasterDataSyncService().syncToAWS();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.orderSaved)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.saveOrderError(e.toString())), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Category Section Builder ---
  Widget _buildCategorySection(String category) {
    final rows = _categorizedDishes[category]!;
    final suggestions = _dishSuggestions[category] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              TextButton.icon(
                onPressed: () => _addDishRow(category),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocalizations.of(context)!.addItem),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        
        // Rows
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final dish = entry.value;
          return DishRowItem(
            key: ValueKey(dish['_localId'] ?? ObjectKey(dish)), // Fallback if ID missing
            dish: dish,
            suggestions: suggestions,
            category: category,
            index: index,
            totalPax: _pax,
            parentSetState: (fn) => setState(fn),
            recalculateTotals: _recalculateTotals,
            onDelete: (idx) {
              setState(() {
                _categorizedDishes[category]!.removeAt(idx);
                _recalculateTotals();
              });
            },
          );
        }),
        
        const SizedBox(height: 16),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingOrder != null;
    final dateStr = '${widget.date.day}/${widget.date.month}/${widget.date.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? AppLocalizations.of(context)!.editOrder : AppLocalizations.of(context)!.addOrder),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              // --- Header Info ---
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.dateLabel(dateStr),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      initialValue: _pax.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Total Pax',
                        isDense: true,
                      ),
                      onChanged: (v) {
                        final newPax = int.tryParse(v) ?? 0;
                        setState(() {
                          _pax = newPax;
                          // Update all dish rows with the new pax value
                          for (var cat in _categories) {
                            for (final dish in _categorizedDishes[cat]!) {
                              // Update pax for all rows (user can still manually edit)
                              dish['pax'] = newPax;
                            }
                          }
                          _recalculateTotals();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Time Picker Row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime ?? TimeOfDay.now(),
                          builder: (context, child) {
                            return Localizations.override(
                              context: context,
                              locale: const Locale('en'),
                              child: child,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
                        }
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.deliveryTime,
                            hintText: AppLocalizations.of(context)!.tapToSelectTime,
                            suffixIcon: const Icon(Icons.access_time),
                          ),
                          controller: TextEditingController(
                            text: _selectedTime != null
                                ? _selectedTime!.format(context)
                                : '',
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedTime != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () => setState(() => _selectedTime = null),
                      tooltip: 'Clear time',
                    ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _customerController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.customerName),
                validator: (v) => (v == null || v.trim().isEmpty) ? AppLocalizations.of(context)!.required : null,
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.mobile,
                  counterText: '',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return null; // Optional field - empty is OK
                  }
                  // If anything is entered, must be exactly 10 digits
                  final cleaned = v.trim();
                  if (!RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
                    return AppLocalizations.of(context)!.digitsOnly;
                  }
                  if (cleaned.length != 10) {
                    return AppLocalizations.of(context)!.mobileLengthError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.location),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _mealType,
                      items: [
                        DropdownMenuItem(value: 'Breakfast', child: Text(AppLocalizations.of(context)!.breakfast)),
                        DropdownMenuItem(value: 'Lunch', child: Text(AppLocalizations.of(context)!.lunch)),
                        DropdownMenuItem(value: 'Dinner', child: Text(AppLocalizations.of(context)!.dinner)),
                        DropdownMenuItem(value: 'Snacks/Others', child: Text(AppLocalizations.of(context)!.snacksOthers)),
                      ],
                      onChanged: (v) => setState(() => _mealType = v ?? 'Lunch'),
                      decoration: InputDecoration(labelText: AppLocalizations.of(context)!.mealType),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _foodType,
                      items: [
                        DropdownMenuItem(value: 'Veg', child: Text(AppLocalizations.of(context)!.veg)),
                        DropdownMenuItem(value: 'Non-Veg', child: Text(AppLocalizations.of(context)!.nonVeg)),
                      ],
                      onChanged: (v) => setState(() => _foodType = v ?? 'Veg'),
                      decoration: InputDecoration(labelText: AppLocalizations.of(context)!.foodType),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- Categorized Dishes Sections ---
              Text(
                AppLocalizations.of(context)!.menuItems,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              ..._categories.map((cat) => _buildCategorySection(cat)),

              const SizedBox(height: 20),

              // --- Pricing & Save ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.blue.shade50,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('bd_$_beforeDiscount'), // force rebuild on update
                            initialValue: _beforeDiscount.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.subtotal),
                            onChanged: (v) {
                              _beforeDiscount = double.tryParse(v) ?? 0;
                              _recalculateTotals();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            initialValue: _discountPercent.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.discPercent),
                            onChanged: (v) {
                              _discountPercent = double.tryParse(v) ?? 0;
                              _recalculateTotals();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLocalizations.of(context)!.dishTotal, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('₹${_finalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // ===== SERVICE & COUNTER SETUP SECTION =====
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context)!.serviceAndCounterSetup, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(),
                      
                      // Service Required Toggle
                      SwitchListTile(
                        title: Text(AppLocalizations.of(context)!.serviceRequiredQuestion),
                        value: _serviceRequired,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() {
                          _serviceRequired = v;
                          _recalculateServiceCosts();
                        }),
                      ),
                      
                      if (_serviceRequired) ...[
                        // Service Type Dropdown
                        Row(
                          children: [
                            Text(AppLocalizations.of(context)!.serviceType),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _serviceType,
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                items: const [
                                  DropdownMenuItem(value: 'BUFFET', child: Text('Buffet')),
                                  DropdownMenuItem(value: 'TABLE_SERVICE', child: Text('Table Service')),
                                  DropdownMenuItem(value: 'HYBRID', child: Text('Both (Hybrid)')),
                                ],
                                onChanged: (v) => setState(() {
                                  _serviceType = v ?? 'BUFFET';
                                  _recalculateServiceCosts();
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Counter Count & Staff Rate
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: _counterCount.toString(),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.countersCount, isDense: true),
                                onChanged: (v) => setState(() {
                                  _counterCount = int.tryParse(v) ?? 1;
                                  if (_counterCount < 1) _counterCount = 1;
                                  _recalculateServiceCosts();
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: _staffRate > 0 ? _staffRate.toStringAsFixed(0) : '',
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.ratePerStaff, isDense: true),
                                onChanged: (v) => setState(() {
                                  _staffRate = double.tryParse(v) ?? 0;
                                  _recalculateServiceCosts();
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Staff Count (Editable)
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _staffCountController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.staffRequired, isDense: true),
                                onChanged: (v) => setState(() {
                                  _isStaffInfoManual = true;
                                  _staffCount = int.tryParse(v) ?? 0;
                                  _recalculateServiceCosts();
                                }),
                              ),
                            ),
                            if (_isStaffInfoManual)
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 20, color: Colors.blue),
                                tooltip: AppLocalizations.of(context)!.resetCalculation,
                                onPressed: () => setState(() {
                                  _isStaffInfoManual = false;
                                  _recalculateServiceCosts();
                                }),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Text(AppLocalizations.of(context)!.costWithRupee(_serviceCost.toStringAsFixed(0)), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 8),
                      
                      // Counter Setup Toggle
                      SwitchListTile(
                        title: Text(AppLocalizations.of(context)!.counterSetupNeeded),
                        value: _counterSetupRequired,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() {
                          _counterSetupRequired = v;
                          _recalculateServiceCosts();
                        }),
                      ),
                      
                      if (_counterSetupRequired) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: _counterSetupRate > 0 ? _counterSetupRate.toStringAsFixed(0) : '',
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.ratePerCounter, isDense: true),
                                onChanged: (v) => setState(() {
                                  _counterSetupRate = double.tryParse(v) ?? 0;
                                  _recalculateServiceCosts();
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(AppLocalizations.of(context)!.counterCostWithRupee(_counterSetupCost.toStringAsFixed(0)), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                      
                      const Divider(),
                      
                      // Grand Total Breakdown
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               Text(AppLocalizations.of(context)!.dishTotal, style: const TextStyle(fontSize: 14)),
                               Text(_canViewRates ? '₹${_beforeDiscount.toStringAsFixed(0)}' : '****', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          if (_discountAmount > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               Text(AppLocalizations.of(context)!.discountWithPercent(_discountPercent.toStringAsFixed(1)), style: const TextStyle(fontSize: 14, color: Colors.green)),
                               Text(_canViewRates ? '-₹${_discountAmount.toStringAsFixed(0)}' : '****', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.green)),
                            ],
                          ),
                          if (_serviceCost > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               Text(AppLocalizations.of(context)!.serviceCost, style: const TextStyle(fontSize: 14)),
                               Text(_canViewRates ? '+₹${_serviceCost.toStringAsFixed(0)}' : '****', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          if (_counterSetupCost > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               Text(AppLocalizations.of(context)!.counterSetup, style: const TextStyle(fontSize: 14)),
                               Text(_canViewRates ? '+₹${_counterSetupCost.toStringAsFixed(0)}' : '****', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(thickness: 1.5),
                      // Grand Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppLocalizations.of(context)!.grandTotal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(_canViewRates ? '₹${_grandTotal.toStringAsFixed(0)}' : '****', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.notes),
              ),
              const SizedBox(height: 24),

              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(AppLocalizations.of(context)!.saveOrder, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customerController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _staffCountController.dispose();
    super.dispose();
  }
}

class DishRowItem extends StatefulWidget {
  final Map<String, dynamic> dish;
  final List<Map<String, dynamic>> suggestions;
  final String category;
  final int index;
  final int totalPax; // To check against for auto-fill
  final Function(VoidCallback fn) parentSetState; // To call setState in parent
  final Function() recalculateTotals;
  final Function(int index) onDelete;

  const DishRowItem({
    super.key,
    required this.dish,
    required this.suggestions,
    required this.category,
    required this.index,
    required this.totalPax,
    required this.parentSetState,
    required this.recalculateTotals,
    required this.onDelete,
  });

  @override
  State<DishRowItem> createState() => _DishRowItemState();
}

class _DishRowItemState extends State<DishRowItem> {
  late TextEditingController _rateController;
  late TextEditingController _qtyController;
  late TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    _rateController = TextEditingController(text: _formatNum(widget.dish['rate']));
    _qtyController = TextEditingController(text: (widget.dish['pax'] ?? 0).toString());
    _costController = TextEditingController(text: _formatNum(widget.dish['cost']));
  }

  String _formatNum(dynamic v) {
    if (v == null) return '0';
    if (v is int) return v.toString();
    double d = v is double ? v : double.tryParse(v.toString()) ?? 0;
    if (d == d.toInt()) return d.toInt().toString();
    return d.toStringAsFixed(2);
  }

  @override
  void didUpdateWidget(covariant DishRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Fix: Updating controllers notifies Form, triggering setState on ancestor Form during build.
    // Wrap in addPostFrameCallback to avoid this.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Rate check
      final currentRate = double.tryParse(_rateController.text) ?? 0;
      final dishRate = double.tryParse(widget.dish['rate']?.toString() ?? '0') ?? 0;
      if ((currentRate - dishRate).abs() > 0.01) {
         _rateController.text = _formatNum(dishRate);
      }

      // Qty Check
      final currentQty = int.tryParse(_qtyController.text) ?? 0;
      final dishQty = widget.dish['pax'] ?? 0;
      if (currentQty != dishQty) {
         _qtyController.text = dishQty.toString();
      }
      
      // Cost Check
      final currentCost = double.tryParse(_costController.text) ?? 0;
      final dishCost = double.tryParse(widget.dish['cost']?.toString() ?? '0') ?? 0;
      if ((currentCost - dishCost).abs() > 1.0) {
         _costController.text = _formatNum(dishCost);
      }
    });
  }

  @override
  void dispose() {
    _rateController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Dish Name with Autocomplete
          Expanded(
            flex: 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Try to find master ID for localization
                int? masterId;
                final currentName = widget.dish['name']?.toString() ?? '';
                if (currentName.isNotEmpty) {
                  try {
                    final match = widget.suggestions.firstWhere(
                      (s) => s['name'] == currentName,
                      orElse: () => {},
                    );
                    if (match.isNotEmpty) masterId = match['id'] as int?;
                  } catch (_) {}
                }

                String localizedLabel = '';
                if (masterId != null) {
                  localizedLabel = LanguageService().getLocalizedName(
                    entityType: 'DISH',
                    entityId: masterId,
                    defaultName: '',
                  );
                  // Don't show if same as english (or default)
                  if (localizedLabel == currentName) localizedLabel = '';
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return widget.suggestions;
                        }
                        // Filter by English Name OR Localized Name
                        return widget.suggestions.where((s) {
                          final name = s['name']?.toString().toLowerCase() ?? '';
                          // Check English
                          if (name.contains(textEditingValue.text.toLowerCase())) return true;
                          
                          // Check Localized
                          final loc = LanguageService().getLocalizedName(
                            entityType: 'DISH',
                            entityId: s['id'] as int,
                            defaultName: ''
                          ).toLowerCase();
                          return loc.contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      displayStringForOption: (option) => option['name']?.toString() ?? '',
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        if (controller.text.isEmpty && widget.dish['name'] != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (controller.text.isEmpty && mounted) {
                              controller.text = widget.dish['name'].toString();
                            }
                          });
                        }
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.typeDishName,
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            border: const OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (val) {
                            widget.parentSetState(() {
                              widget.dish['name'] = val.isNotEmpty ? val : null;
                              if (val.isNotEmpty && (widget.dish['pax'] ?? 0) == 0 && widget.totalPax > 0) {
                                widget.dish['pax'] = widget.totalPax;
                              }
                              widget.recalculateTotals();
                            });
                          },
                        );
                      },
                      onSelected: (option) {
                        widget.parentSetState(() {
                          widget.dish['name'] = option['name'];
                          widget.dish['rate'] = (option['rate'] is int) 
                              ? (option['rate'] as int).toDouble() 
                              : (option['rate'] != null ? (option['rate'] is double ? option['rate'] : double.tryParse(option['rate'].toString()) ?? 0.0) : 0.0);
                              
                          if ((widget.dish['pax'] ?? 0) == 0 && widget.totalPax > 0) {
                            widget.dish['pax'] = widget.totalPax;
                          }
                          widget.recalculateTotals();
                        });
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 250),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, i) {
                                  final opt = options.elementAt(i);
                                  final locName = LanguageService().getLocalizedName(
                                    entityType: 'DISH',
                                    entityId: opt['id'] as int,
                                    defaultName: opt['name'],
                                  );
                                  
                                  return ListTile(
                                    dense: true,
                                    // Show Localized Name primarily if language is not English
                                    title: Text(locName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    subtitle: locName != opt['name'] ? Text(opt['name']) : null,
                                    trailing: Text('₹${opt['rate'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    onTap: () => onSelected(opt),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (localizedLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 4),
                        child: Text(
                          localizedLabel,
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey[700], fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                );
              }
            ),
          ),
          const SizedBox(width: 8),

          // 2. Rate (Editable)
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.rate,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) {
                widget.dish['rate'] = double.tryParse(val) ?? 0;
                widget.recalculateTotals(); 
              },
            ),
          ),
          const SizedBox(width: 8),

          // 3. Qty
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.qty,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) {
                widget.dish['pax'] = int.tryParse(val) ?? 0;
                widget.recalculateTotals();
              },
            ),
          ),
          const SizedBox(width: 8),

          // 4. Total Cost (Editable now)
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.cost,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) {
                 final cost = double.tryParse(val) ?? 0;
                 widget.dish['cost'] = cost;
                 
                 final qty = widget.dish['pax'] ?? 0;
                 if (qty > 0) {
                     // Recalculate and update Rate
                     final rate = cost / qty;
                     widget.dish['rate'] = rate;
                 }
                 widget.recalculateTotals();
              },
            ),
          ),
          const SizedBox(width: 8),

          // 5. Delete button
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () => widget.onDelete(widget.index),
            ),
          ),
        ],
      ),
    );
  }
}
