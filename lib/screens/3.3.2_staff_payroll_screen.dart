// MODULE: STAFF PAYROLL (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-08 | Features: Monthly Payroll, OT Calculation, Advance Deductions
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class StaffPayrollScreen extends StatefulWidget {
  const StaffPayrollScreen({super.key});

  @override
  State<StaffPayrollScreen> createState() => _StaffPayrollScreenState();
}

class _StaffPayrollScreenState extends State<StaffPayrollScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _payrollData = [];
  double _otMultiplier = 1.5;
  
  // Selected month
  DateTime _selectedMonth = DateTime.now();
  
  // Totals
  double _totalBasePay = 0;
  double _totalOTPay = 0;
  double _totalAdvances = 0;
  double _totalNetPay = 0;

  @override
  void initState() {
    super.initState();
    _loadPayrollData();
  }

  String get _monthYearStr => DateFormat('yyyy-MM').format(_selectedMonth);
  String get _monthDisplayStr => DateFormat('MMMM yyyy').format(_selectedMonth);

  Future<void> _loadPayrollData() async {
    setState(() => _isLoading = true);
    
    // Get OT multiplier from firm settings
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm');
    if (firmId != null) {
      final firm = await DatabaseHelper().getFirmDetails(firmId);
      if (firm != null && firm['otMultiplier'] != null) {
        _otMultiplier = (firm['otMultiplier'] as num).toDouble();
      }
    }
    
    // Get payroll summary
    final data = await DatabaseHelper().getMonthlyPayrollSummary(_monthYearStr);
    
    // Calculate totals
    _totalBasePay = 0;
    _totalOTPay = 0;
    _totalAdvances = 0;
    _totalNetPay = 0;
    
    final processedData = data.map((staff) {
      final calcs = _calculatePayroll(staff);
      _totalBasePay += calcs['basePay'] as double;
      _totalOTPay += calcs['otPay'] as double;
      _totalAdvances += calcs['advances'] as double;
      _totalNetPay += calcs['netPay'] as double;
      return {...staff, ...calcs};
    }).toList();
    
    setState(() {
      _payrollData = processedData;
      _isLoading = false;
    });
  }

  Map<String, dynamic> _calculatePayroll(Map<String, dynamic> staff) {
    final staffType = staff['staffType'] as String? ?? 'PERMANENT';
    final salary = (staff['salary'] as num?)?.toDouble() ?? 0;
    final dailyWageRate = (staff['dailyWageRate'] as num?)?.toDouble() ?? 0;
    final hourlyRate = (staff['hourlyRate'] as num?)?.toDouble() ?? 0;
    final daysPresent = (staff['daysPresent'] as num?)?.toInt() ?? 0;
    final totalOvertime = (staff['totalOvertime'] as num?)?.toDouble() ?? 0;
    final pendingAdvances = (staff['pendingAdvances'] as num?)?.toDouble() ?? 0;
    
    double basePay = 0;
    
    switch (staffType) {
      case 'PERMANENT':
        // Pro-rated salary based on days present (assuming 30-day month)
        basePay = (salary / 30) * daysPresent;
        break;
      case 'DAILY_WAGE':
        basePay = dailyWageRate * daysPresent;
        break;
      case 'CONTRACTOR':
        basePay = salary; // Fixed amount for contractors
        break;
    }
    
    // OT Pay: overtime hours × hourly rate × multiplier
    final otPay = totalOvertime * hourlyRate * _otMultiplier;
    
    // Net Pay
    final netPay = basePay + otPay - pendingAdvances;
    
    return {
      'basePay': basePay,
      'otPay': otPay,
      'advances': pendingAdvances,
      'netPay': netPay,
    };
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadPayrollData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedMonth.year < now.year || 
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month)) {
      setState(() {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      });
      _loadPayrollData();
    }
  }

  Future<void> _processPayroll(int staffId, String staffName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.processPayroll),
        content: Text(AppLocalizations.of(context)!.processPayrollConfirm(staffName, _monthDisplayStr)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await DatabaseHelper().markAdvancesDeducted(staffId, _monthYearStr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.payrollProcessed(staffName)), backgroundColor: Colors.green),
      );
      _loadPayrollData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.staffPayroll),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPayrollData),
        ],
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Text(
                  _monthDisplayStr,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: _selectedMonth.month == DateTime.now().month ? Colors.grey : null,
                  ),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          
          // Summary Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildSummaryCard(AppLocalizations.of(context)!.basePay, _totalBasePay, Colors.blue),
                const SizedBox(width: 8),
                _buildSummaryCard(AppLocalizations.of(context)!.otPay, _totalOTPay, Colors.orange),
                const SizedBox(width: 8),
                _buildSummaryCard(AppLocalizations.of(context)!.advances, _totalAdvances, Colors.red),
                const SizedBox(width: 8),
                _buildSummaryCard(AppLocalizations.of(context)!.netPay, _totalNetPay, Colors.green),
              ],
            ),
          ),
          
          // OT Multiplier Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppLocalizations.of(context)!.otMultiplierInfo(_otMultiplier.toString()),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 8),
          
          // Payroll List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _payrollData.isEmpty
                    ? Center(child: Text(AppLocalizations.of(context)!.noStaffData))
                    : ListView.builder(
                        itemCount: _payrollData.length,
                        itemBuilder: (context, index) => _buildPayrollCard(_payrollData[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '₹${value.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollCard(Map<String, dynamic> staff) {
    final name = staff['name'] as String? ?? AppLocalizations.of(context)!.unknown;
    final staffType = staff['staffType'] as String? ?? AppLocalizations.of(context)!.permanent;
    final daysPresent = (staff['daysPresent'] as num?)?.toInt() ?? 0;
    final totalOT = (staff['totalOvertime'] as num?)?.toDouble() ?? 0;
    final basePay = (staff['basePay'] as num?)?.toDouble() ?? 0;
    final otPay = (staff['otPay'] as num?)?.toDouble() ?? 0;
    final advances = (staff['advances'] as num?)?.toDouble() ?? 0;
    final netPay = (staff['netPay'] as num?)?.toDouble() ?? 0;
    
    Color typeColor;
    switch (staffType) {
      case 'PERMANENT': typeColor = Colors.green; break;
      case 'DAILY_WAGE': typeColor = Colors.orange; break;
      case 'CONTRACTOR': typeColor = Colors.purple; break;
      default: typeColor = Colors.grey;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: typeColor,
          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(staffType, style: TextStyle(fontSize: 10, color: typeColor)),
            ),
            const SizedBox(width: 8),
            Text('$daysPresent days | ${totalOT.toStringAsFixed(1)}h OT', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₹${netPay.toStringAsFixed(0)}', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
            Text(AppLocalizations.of(context)!.netPay, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPayrollRow(AppLocalizations.of(context)!.basePay, basePay, Colors.blue),
                _buildPayrollRow('${AppLocalizations.of(context)!.otPay} (${totalOT.toStringAsFixed(1)}h × ${_otMultiplier}x)', otPay, Colors.orange),
                if (advances > 0)
                  _buildPayrollRow(AppLocalizations.of(context)!.advanceDeduction, -advances, Colors.red),
                const Divider(),
                _buildPayrollRow(AppLocalizations.of(context)!.netPayable, netPay, Colors.green, bold: true),
                const SizedBox(height: 12),
                if (advances > 0)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _processPayroll(staff['id'], name),
                      icon: const Icon(Icons.check),
                      label: Text(AppLocalizations.of(context)!.markAdvancesDeducted),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollRow(String label, double value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            '${value >= 0 ? '+' : ''}₹${value.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
