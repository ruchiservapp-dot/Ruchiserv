import 'package:flutter/material.dart';
import '../../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? type; // INCOME or EXPENSE
  const AddTransactionScreen({super.key, this.type});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late String _type;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  
  String _selectedCategory = 'Other';
  String _selectedMode = 'Cash';
  DateTime _selectedDate = DateTime.now();
  bool _isGlobal = false; // If implemented, to select Firm scope. Default to DEFAULT firm.

  final List<String> _incomeCategories = ['Sales', 'Services', 'Refund', 'Investment', 'Other'];
  final List<String> _expenseCategories = ['Groceries', 'Salary', 'Rent', 'Utilities', 'Maintenance', 'Fuel', 'Other'];
  final List<String> _modes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque'];

  @override
  void initState() {
    super.initState();
    _type = widget.type ?? 'INCOME';
    _selectedCategory = _type == 'INCOME' ? _incomeCategories.first : _expenseCategories.first;
    _dateController.text = _selectedDate.toString().split(' ')[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_type == 'INCOME' ? AppLocalizations.of(context)!.addIncome : AppLocalizations.of(context)!.addExpense),
        backgroundColor: _type == 'INCOME' ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Type Selector
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text(AppLocalizations.of(context)!.income)),
                      selected: _type == 'INCOME',
                      selectedColor: Colors.green.shade100,
                      onSelected: (val) {
                        setState(() {
                          _type = 'INCOME';
                          _selectedCategory = _incomeCategories.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text(AppLocalizations.of(context)!.expense)),
                      selected: _type == 'EXPENSE',
                      selectedColor: Colors.red.shade100,
                      onSelected: (val) {
                        setState(() {
                          _type = 'EXPENSE';
                          _selectedCategory = _expenseCategories.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.amountLabel,
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return AppLocalizations.of(context)!.enterAmount;
                  if (double.tryParse(val) == null) return AppLocalizations.of(context)!.invalidAmount;
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.categoryLabel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: (_type == 'INCOME' ? _incomeCategories : _expenseCategories)
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 16),

              // Date
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.dateLabel,
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _dateController.text = picked.toString().split(' ')[0];
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Mode
              DropdownButtonFormField<String>(
                value: _selectedMode,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.paymentModeLabel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setState(() => _selectedMode = val!),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.descriptionLabel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveTransaction,
                  child: Text(AppLocalizations.of(context)!.saveTransaction, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);
    final data = {
      'firmId': 'DEFAULT', // TODO: From Auth
      'date': _selectedDate.toIso8601String(),
      'type': _type,
      'amount': amount,
      'category': _selectedCategory,
      'description': _descriptionController.text,
      'mode': _selectedMode,
    };

    try {
      await DatabaseHelper().insertTransaction(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.transactionSaved)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
