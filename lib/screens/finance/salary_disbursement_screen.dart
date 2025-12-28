// MODULE: SALARY DISBURSEMENT SCREEN
// Finance/Admin view to manage and disburse staff salaries
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';

class SalaryDisbursementScreen extends StatefulWidget {
  const SalaryDisbursementScreen({super.key});

  @override
  State<SalaryDisbursementScreen> createState() => _SalaryDisbursementScreenState();
}

class _SalaryDisbursementScreenState extends State<SalaryDisbursementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];
  DateTime _selectedMonth = DateTime.now();
  String? _firmId;
  double _otMultiplier = 1.5;
  
  // Totals
  double _totalPayable = 0;
  double _totalPaid = 0;
  int _pendingCount = 0;
  int _paidCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _monthYear => DateFormat('yyyy-MM').format(_selectedMonth);
  String get _monthDisplay => DateFormat('MMMM yyyy').format(_selectedMonth);

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final sp = await SharedPreferences.getInstance();
    _firmId = sp.getString('last_firm');
    
    if (_firmId == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    final db = DatabaseHelper();
    
    // Get OT multiplier
    final firm = await db.getFirmDetails(_firmId!);
    if (firm != null && firm['otMultiplier'] != null) {
      _otMultiplier = (firm['otMultiplier'] as num).toDouble();
    }
    
    // Get disbursements data
    final data = await db.getPendingDisbursements(_firmId!, _monthYear);
    
    // Calculate totals and payroll for each staff
    _totalPayable = 0;
    _totalPaid = 0;
    _pendingCount = 0;
    _paidCount = 0;
    
    final processedData = data.map((staff) {
      final calcs = _calculatePayroll(staff);
      final isPaid = staff['disbursementStatus'] == 'PAID';
      
      if (isPaid) {
        _paidCount++;
        _totalPaid += (staff['paidAmount'] as num?)?.toDouble() ?? 0;
      } else {
        _pendingCount++;
        _totalPayable += calcs['netPay'] as double;
      }
      
      return {...staff, ...calcs};
    }).toList();
    
    setState(() {
      _staffList = processedData;
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
        basePay = (salary / 30) * daysPresent;
        break;
      case 'DAILY_WAGE':
        basePay = dailyWageRate * daysPresent;
        break;
      case 'CONTRACTOR':
        basePay = salary;
        break;
    }
    
    final otPay = totalOvertime * hourlyRate * _otMultiplier;
    final netPay = basePay + otPay - pendingAdvances;
    
    return {
      'basePay': basePay,
      'otPay': otPay,
      'deductions': pendingAdvances,
      'netPay': netPay,
    };
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedMonth.year < now.year || 
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month)) {
      setState(() {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      });
      _loadData();
    }
  }

  Future<void> _disburseSalary(Map<String, dynamic> staff) async {
    final staffId = staff['id'] as int;
    final staffName = staff['name'] as String;
    final netPay = (staff['netPay'] as num).toDouble();
    
    String? selectedMode;
    String? paymentRef;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Disburse Salary - $staffName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount: ₹${netPay.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['CASH', 'BANK', 'UPI'].map((mode) {
                  final isSelected = selectedMode == mode;
                  return ChoiceChip(
                    label: Text(mode),
                    selected: isSelected,
                    onSelected: (sel) {
                      setDialogState(() => selectedMode = sel ? mode : null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Reference (Optional)',
                  hintText: 'Transaction ID',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) => paymentRef = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedMode == null 
                  ? null 
                  : () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed == true && selectedMode != null && _firmId != null) {
      try {
        await DatabaseHelper().disburseSalary(
          firmId: _firmId!,
          staffId: staffId,
          monthYear: _monthYear,
          basePay: (staff['basePay'] as num).toDouble(),
          otPay: (staff['otPay'] as num).toDouble(),
          deductions: (staff['deductions'] as num).toDouble(),
          netPay: netPay,
          paymentMode: selectedMode!,
          paymentRef: paymentRef,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Salary disbursed to $staffName'), backgroundColor: Colors.green),
          );
        }
        
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Disbursement'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Month Selector
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  color: Colors.indigo.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _previousMonth,
                      ),
                      Text(
                        _monthDisplay,
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildSummaryCard('Pending', _pendingCount, _totalPayable, Colors.orange),
                      const SizedBox(width: 12),
                      _buildSummaryCard('Paid', _paidCount, _totalPaid, Colors.green),
                    ],
                  ),
                ),
                
                // Staff List
                Expanded(
                  child: _staffList.isEmpty
                      ? const Center(child: Text('No staff data for this month'))
                      : ListView.builder(
                          itemCount: _staffList.length,
                          itemBuilder: (context, index) => _buildStaffCard(_staffList[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(String title, int count, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
            const SizedBox(height: 8),
            Text('$count staff', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final name = staff['name'] as String? ?? 'Unknown';
    final staffType = staff['staffType'] as String? ?? 'PERMANENT';
    final daysPresent = (staff['daysPresent'] as num?)?.toInt() ?? 0;
    final totalOT = (staff['totalOvertime'] as num?)?.toDouble() ?? 0;
    final basePay = (staff['basePay'] as num?)?.toDouble() ?? 0;
    final otPay = (staff['otPay'] as num?)?.toDouble() ?? 0;
    final deductions = (staff['deductions'] as num?)?.toDouble() ?? 0;
    final netPay = (staff['netPay'] as num?)?.toDouble() ?? 0;
    final isPaid = staff['disbursementStatus'] == 'PAID';
    final paidAmount = (staff['paidAmount'] as num?)?.toDouble() ?? 0;
    
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
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: typeColor,
              child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
            ),
            if (isPaid)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
          ],
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
            Text('$daysPresent days', style: const TextStyle(fontSize: 12)),
            if (totalOT > 0) Text(' • ${totalOT.toStringAsFixed(1)}h OT', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${(isPaid ? paidAmount : netPay).toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                color: isPaid ? Colors.green : Colors.indigo,
              ),
            ),
            Text(
              isPaid ? 'PAID' : 'Pending',
              style: TextStyle(
                fontSize: 10, 
                color: isPaid ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPayrollRow('Base Pay', basePay, Colors.blue),
                _buildPayrollRow('OT Pay (${totalOT.toStringAsFixed(1)}h @ ${_otMultiplier}x)', otPay, Colors.orange),
                if (deductions > 0)
                  _buildPayrollRow('Advances Deduction', -deductions, Colors.red),
                const Divider(),
                _buildPayrollRow('Net Payable', netPay, Colors.green, bold: true),
                const SizedBox(height: 12),
                if (!isPaid && netPay > 0)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _disburseSalary(staff),
                      icon: const Icon(Icons.payments),
                      label: const Text('Disburse Salary'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (isPaid)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Paid via ${staff['paymentMode'] ?? '-'} on ${staff['paidAt']?.toString().substring(0, 10) ?? '-'}',
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ),
                      ],
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
