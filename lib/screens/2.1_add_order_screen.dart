// lib/screens/2.1_add_order_screen.dart
import 'package:flutter/material.dart';
import '../db/database_helper.dart';

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

  // Order core fields (same front-end logic as before)
  String _mealType = 'Lunch';
  String _foodType = 'Veg';
  int _pax = 0;

  double _beforeDiscount = 0;
  double _discountPercent = 0;
  double _finalAmount = 0;

  bool _isSaving = false;

  // Dishes: each item = {name, category, foodType, pax, rate, cost}
  final List<Map<String, dynamic>> _dishes = [];

  // Settings matching earlier decisions
  bool _autoFillQtyByPax = true; // auto-fill qty = pax on open (editable)

  // Sample Menu Master (you can swap to fetch from DB later)
  // Keep names simple; rate in ₹ per qty
  static const _menuRates = {
    'Starters': {
      'Veg Cutlet': 25,
      'Paneer Tikka': 45,
      'Chicken 65': 60,
    },
    'Main Course': {
      'Veg Fried Rice': 60,
      'Chicken Biriyani': 120,
      'Paneer Butter Masala': 110,
    },
    'Specials': {
      'Gulab Jamun': 20,
      'Fruit Salad': 30,
      'Ice Cream': 35,
    }
  };

  @override
  void initState() {
    super.initState();
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

      // If you stored dishes, you can preload here
      // (Optional) Left as-is to keep front-end logic unchanged.
    }
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
    }

  void _recalculateTotals() {
    double sum = 0;
    for (final d in _dishes) {
      final qty = _parseInt(d['pax']) ?? 0;
      final rate = _parseInt(d['rate']) ?? 0;
      final cost = qty * rate;
      d['cost'] = cost;
      sum += cost;
    }
    _beforeDiscount = sum;
    _finalAmount = sum - (sum * (_discountPercent / 100));
    setState(() {});
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final dateStr = widget.date.toIso8601String().split('T').first;

      // order map aligned with your local DB schema (DatabaseHelper)
      final order = <String, dynamic>{
        'date': dateStr,
        'customerName': _customerController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'email': null,
        'location': _locationController.text.trim(),
        'mealType': _mealType,
        'foodType': _foodType,
        'time': null,
        'notes': _notesController.text.trim(),
        'beforeDiscount': _beforeDiscount,
        'discountPercent': _discountPercent,
        'discountAmount': (_beforeDiscount * _discountPercent / 100).round(),
        'finalAmount': _finalAmount,
        'totalPax': _pax,
        'isLocked': 0,
      };

      // prepare dishes payload for DB
      final dishRows = _dishes
          .where((d) => (_parseInt(d['pax']) ?? 0) > 0)
          .map((d) => {
                'name': d['name'],
                'foodType': d['foodType'] ?? _foodType,
                'pax': _parseInt(d['pax']) ?? 0,
                'rate': _parseInt(d['rate']) ?? 0,
                'manualCost': 0,
                'cost': _parseInt(d['cost']) ?? 0,
                'category': d['category'],
              })
          .toList();

      if (widget.existingOrder != null) {
        // update
        await DatabaseHelper().updateOrder(
          widget.existingOrder!['id'] as int,
          order,
          dishRows,
        );
      } else {
        // insert
        final id = await DatabaseHelper().insertOrder(order, dishRows);
        if (id == null || id <= 0) {
          throw Exception('Insert failed');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Order saved')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving order: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openDishPicker() async {
    // Build initial qty map for the sheet
    final Map<String, TextEditingController> qtyCtrls = {};
    for (final cat in _menuRates.keys) {
      for (final name in _menuRates[cat]!.keys) {
        final key = '$cat|$name';
        final c = TextEditingController();
        // auto-fill qty = pax only if enabled and empty
        if (_autoFillQtyByPax) c.text = _pax.toString();
        qtyCtrls[key] = c;
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (_, __) {
            return DefaultTabController(
              length: _menuRates.keys.length,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Add Dishes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Text('Auto-qty by Pax'),
                            Switch(
                              value: _autoFillQtyByPax,
                              onChanged: (v) {
                                setState(() => _autoFillQtyByPax = v);
                                // Update current controllers
                                if (v) {
                                  for (final c in qtyCtrls.values) {
                                    if ((c.text).trim().isEmpty) {
                                      c.text = _pax.toString();
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tabs
                  TabBar(
                    isScrollable: true,
                    labelColor: Colors.blue.shade700,
                    unselectedLabelColor: Colors.black54,
                    tabAlignment: TabAlignment.start,
                    tabs: _menuRates.keys
                        .map((cat) => Tab(text: cat))
                        .toList(),
                  ),
                  const Divider(height: 1),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      children: _menuRates.keys.map((cat) {
                        final items = _menuRates[cat]!;
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final name = items.keys.elementAt(idx);
                            final rate = items[name]!;
                            final key = '$cat|$name';
                            final ctrl = qtyCtrls[key]!;

                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text('Rate: ₹$rate'),
                                trailing: SizedBox(
                                  width: 96,
                                  child: TextField(
                                    controller: ctrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 10),
                                      hintText: 'Qty',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  // Add Selected
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 8,
                          color: Colors.black.withOpacity(0.08),
                          offset: const Offset(0, -2),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // collect non-zero qty
                              final picked = <Map<String, dynamic>>[];
                              for (final cat in _menuRates.keys) {
                                for (final name in _menuRates[cat]!.keys) {
                                  final key = '$cat|$name';
                                  final q = int.tryParse(qtyCtrls[key]!.text) ?? 0;
                                  if (q > 0) {
                                    final rate = _menuRates[cat]![name]!;
                                    picked.add({
                                      'name': name,
                                      'category': cat,
                                      'foodType': _foodType,
                                      'pax': q,
                                      'rate': rate,
                                      'cost': q * rate,
                                    });
                                  }
                                }
                              }
                              // merge or replace same-name rows by summing qty
                              for (final p in picked) {
                                final idx = _dishes.indexWhere(
                                  (d) => d['name'] == p['name'] && d['category'] == p['category'],
                                );
                                if (idx >= 0) {
                                  _dishes[idx]['pax'] =
                                      (_parseInt(_dishes[idx]['pax']) ?? 0) +
                                          (_parseInt(p['pax']) ?? 0);
                                } else {
                                  _dishes.add(p);
                                }
                              }
                              _recalculateTotals();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Selected'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _dishRow(Map<String, dynamic> d) {
    final qty = _parseInt(d['pax']) ?? 0;
    final rate = _parseInt(d['rate']) ?? 0;
    final cost = qty * rate;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(
          d['name'] ?? 'Unnamed',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${d['category']} • ₹$rate'),
        trailing: SizedBox(
          width: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  final q = (_parseInt(d['pax']) ?? 0) - 1;
                  d['pax'] = q < 0 ? 0 : q;
                  _recalculateTotals();
                },
              ),
              Text('$qty'),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  d['pax'] = (_parseInt(d['pax']) ?? 0) + 1;
                  _recalculateTotals();
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  _dishes.remove(d);
                  _recalculateTotals();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingOrder != null;
    final dateStr =
        '${widget.date.day}/${widget.date.month}/${widget.date.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Order' : 'Add Order'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // date + pax inline
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Date: $dateStr',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      initialValue: _pax.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Pax',
                        isDense: true,
                      ),
                      onChanged: (v) {
                        _pax = int.tryParse(v) ?? 0;
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _customerController,
                decoration: const InputDecoration(labelText: 'Customer Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile'),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: _mealType,
                items: const [
                  DropdownMenuItem(value: 'Breakfast', child: Text('Breakfast')),
                  DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
                  DropdownMenuItem(value: 'Dinner', child: Text('Dinner')),
                  DropdownMenuItem(
                      value: 'Snacks/Others', child: Text('Snacks/Others')),
                ],
                onChanged: (v) => setState(() => _mealType = v ?? 'Lunch'),
                decoration: const InputDecoration(labelText: 'Meal Type'),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: _foodType,
                items: const [
                  DropdownMenuItem(value: 'Veg', child: Text('Veg')),
                  DropdownMenuItem(value: 'Non-Veg', child: Text('Non-Veg')),
                ],
                onChanged: (v) => setState(() => _foodType = v ?? 'Veg'),
                decoration: const InputDecoration(labelText: 'Food Type'),
              ),
              const SizedBox(height: 8),

              // Pricing block
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _beforeDiscount.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Before Discount (₹)'),
                      onChanged: (v) {
                        _beforeDiscount = double.tryParse(v) ?? 0;
                        _recalculateTotals();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    child: TextFormField(
                      initialValue: _discountPercent.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Discount %'),
                      onChanged: (v) {
                        _discountPercent = double.tryParse(v) ?? 0;
                        _recalculateTotals();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              TextFormField(
                initialValue: _finalAmount.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Final Amount (₹)'),
                onChanged: (v) {
                  _finalAmount = double.tryParse(v) ?? 0;
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 16),

              // Dishes section
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Dishes',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openDishPicker,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Dishes'),
                  )
                ],
              ),
              const SizedBox(height: 8),

              if (_dishes.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey.shade100,
                  ),
                  child: const Text(
                    'No dishes added yet.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                ..._dishes.map(_dishRow),

              const SizedBox(height: 16),

              // Totals summary
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.blue.shade50,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sumLine('Before Discount', _beforeDiscount),
                    _sumLine('Discount', _beforeDiscount * _discountPercent / 100),
                    const Divider(),
                    _sumLine('Final Amount', _finalAmount,
                        bold: true, big: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      onPressed: _saveOrder,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sumLine(String label, double amount,
      {bool bold = false, bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
              child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: big ? 16 : 14,
            ),
          )),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              fontSize: big ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _customerController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
