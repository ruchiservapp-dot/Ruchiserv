
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? initialPartyType;
  final String? initialPartyName;
  final int? initialPartyId;

  const AddTransactionScreen({
    super.key, 
    this.initialPartyType,
    this.initialPartyName,
    this.initialPartyId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Fields
  String _type = 'EXPENSE'; // INCOME, EXPENSE
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _partyCtrl = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    if (widget.initialPartyType != null) {
      _partyType = widget.initialPartyType!;
      // Ensure the type is in our dropdown list
      if (!_partyTypes.contains(_partyType)) {
        _partyType = 'Other';
      }
    }
    if (widget.initialPartyName != null) {
      _partyCtrl.text = widget.initialPartyName!;
      _selectedEntityName = widget.initialPartyName;
    }
    if (widget.initialPartyId != null) {
      _selectedEntityId = widget.initialPartyId;
    }
  }

  String _paymentMode = 'Cash';
  DateTime _date = DateTime.now();
  
  // Party Selection
  String _partyType = 'Other'; // Staff, Supplier, Customer, Subcontractor, Other
  int? _selectedEntityId; // if picked from autocomplete
  String? _selectedEntityName; // if picked from autocomplete

  // Dropdown options
  final List<String> _partyTypes = ['Other', 'Staff', 'Supplier', 'Customer', 'Subcontractor'];
  
  // Category Suggestions
  final List<String> _expenseCategories = [
    'Rent', 'Salary', 'Purchase', 'Electricity', 'Fuel', 'Maintenance', 
    'Petty Cash', 'Marketing', 'Internet', 'Water', 'Gas', 'Packaging', 'Transport', 'Other'
  ];
  final List<String> _incomeCategories = ['Sales', 'Advance', 'Refund', 'Catering Service', 'Event Booking', 'Other'];

  bool _isSaving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _partyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final double amount = double.parse(_amountCtrl.text);
      final String category = _categoryCtrl.text.trim();
      final String desc = _descriptionCtrl.text.trim();
      final String partyName = _partyCtrl.text.trim();
      
      final Map<String, dynamic> txn = {
        'firmId': 'DEFAULT', // In real app, get from Auth/Session
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'type': _type,
        'amount': amount,
        'category': category,
        'description': desc.isNotEmpty ? '$desc (Paid to: $partyName)' : 'Paid to: $partyName',
        'mode': _paymentMode,
        'createdAt': DateTime.now().toIso8601String(),
        // New Fields
        'relatedEntityType': _partyType == 'Other' ? null : _partyType.toUpperCase(),
        'relatedEntityId': _selectedEntityId,
      };
      
      await DatabaseHelper().insertTransaction(txn);
      
      if (mounted) {
        Navigator.pop(context, true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaction Saved!")));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Manual Transaction")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Transaction Type
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'INCOME', label: Text("Income"), icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(value: 'EXPENSE', label: Text("Expense"), icon: Icon(Icons.arrow_upward)),
                ], 
                selected: {_type},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _type = newSelection.first;
                    _categoryCtrl.clear();
                  });
                },
                style: ButtonStyle(
                   backgroundColor: MaterialStateProperty.resolveWith((states) {
                     if (states.contains(MaterialState.selected)) {
                       return _type == 'INCOME' ? Colors.green.shade100 : Colors.red.shade100;
                     }
                     return null;
                   })
                ),
              ),
              const SizedBox(height: 20),
              
              // 2. Amount & Date
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context, 
                          initialDate: _date, 
                          firstDate: DateTime(2020), 
                          lastDate: DateTime(2030)
                        );
                        if (d != null) setState(() => _date = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Text(DateFormat('MMM d, yyyy').format(_date)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 3. Category (Autocomplete)
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  final list = _type == 'EXPENSE' ? _expenseCategories : _incomeCategories;
                  return list.where((e) => e.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (val) => _categoryCtrl.text = val,
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  if (_categoryCtrl.text.isNotEmpty && controller.text.isEmpty) {
                     controller.text = _categoryCtrl.text;
                  }
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    onEditingComplete: onEditingComplete,
                    decoration: const InputDecoration(
                      labelText: "Category",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.category),
                    ),
                    validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    onChanged: (val) => _categoryCtrl.text = val,
                  );
                },
              ),
              const SizedBox(height: 20),
              
              // 4. Payment Mode
              DropdownButtonFormField<String>(
                value: _paymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  border: OutlineInputBorder(),
                ),
                items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque'].map((e) => 
                  DropdownMenuItem(value: e, child: Text(e))
                ).toList(),
                onChanged: (v) => setState(() => _paymentMode = v!),
              ),
              const SizedBox(height: 20),

              const Divider(),
              const Text("Party Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              // 5. Party Type
              DropdownButtonFormField<String>(
                value: _partyType,
                decoration: const InputDecoration(labelText: 'Party Type', border: OutlineInputBorder()),
                items: _partyTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() {
                  _partyType = v!;
                  _partyCtrl.clear();
                  _selectedEntityId = null;
                }),
              ),
              const SizedBox(height: 10),

              // 6. Party Name (Dynamic Autocomplete)
              _buildPartyAutocomplete(),
              
              const SizedBox(height: 20),
              
              // 7. Description
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes / Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveTransaction,
                  icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                  label: Text(_isSaving ? "Saving..." : "Save Transaction", style: const TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartyAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (textEditingValue) async {
        if (_partyType == 'Other') return [];
        
        final db = DatabaseHelper();
        List<Map<String, dynamic>> list = [];
        
        if (_partyType == 'Staff') {
          list = await db.getAllStaff(); 
        } else if (_partyType == 'Supplier') {
          list = await db.getAllSuppliers('DEFAULT'); // Using default for now
        } else if (_partyType == 'Subcontractor') {
          list = await db.getAllSubcontractors('DEFAULT');
        } else if (_partyType == 'Customer') {
          list = await db.getAllCustomers('DEFAULT'); 
        }
        
        return list.where((e) {
             final name = (e['name'] ?? '').toString().toLowerCase();
             return name.contains(textEditingValue.text.toLowerCase());
        });
      },
      displayStringForOption: (option) => option['name'] ?? '',
      onSelected: (option) {
         _partyCtrl.text = option['name'];
         _selectedEntityId = option['id'];
         _selectedEntityName = option['name'];
      },
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
         return TextFormField(
           controller: controller,
           focusNode: focusNode,
           onEditingComplete: onEditingComplete,
           decoration: InputDecoration(
             labelText: 'Select ${_partyType == "Other" ? "Party Name" : "$_partyType Name"}',
             border: const OutlineInputBorder(),
             suffixIcon: const Icon(Icons.search),
           ),
           validator: (val) {
             if (_partyType != 'Other' && (val == null || val.isEmpty)) return 'Required for $_partyType';
             return null;
           },
           onChanged: (val) {
              _partyCtrl.text = val;
              // If user types something not in list, clear ID
              if (val != _selectedEntityName) {
                _selectedEntityId = null;
              }
           },
         );
      },
    );
  }
}
