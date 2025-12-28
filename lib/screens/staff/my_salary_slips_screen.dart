// MODULE: MY SALARY SLIPS SCREEN
// Employee self-service to view salary slips and download PDF
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';
import '../../services/report_export_service.dart';

class MySalarySlipsScreen extends StatefulWidget {
  const MySalarySlipsScreen({super.key});

  @override
  State<MySalarySlipsScreen> createState() => _MySalarySlipsScreenState();
}

class _MySalarySlipsScreenState extends State<MySalarySlipsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _staffRecord;
  Map<String, dynamic>? _salaryData;
  List<Map<String, dynamic>> _history = [];
  DateTime _selectedMonth = DateTime.now();
  double _otMultiplier = 1.5;

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
    final userMobile = sp.getString('last_mobile');
    final firmId = sp.getString('last_firm');
    
    if (userMobile == null || firmId == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    final db = DatabaseHelper();
    
    // Find staff record by mobile
    final dbHandle = await db.database;
    final staffList = await dbHandle.query(
      'staff',
      where: 'mobile = ? AND isActive = 1',
      whereArgs: [userMobile],
      limit: 1,
    );
    
    if (staffList.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    
    _staffRecord = staffList.first;
    final staffId = _staffRecord!['id'] as int;
    
    // Get OT multiplier
    final firm = await db.getFirmDetails(firmId);
    if (firm != null && firm['otMultiplier'] != null) {
      _otMultiplier = (firm['otMultiplier'] as num).toDouble();
    }
    
    // Get salary slip data for selected month
    _salaryData = await db.getSalarySlipData(staffId, _monthYear);
    
    // Get history
    _history = await db.getStaffSalaryHistory(staffId, limit: 12);
    
    setState(() => _isLoading = false);
  }

  Map<String, double> _calculatePayroll() {
    if (_staffRecord == null || _salaryData == null) {
      return {'basePay': 0, 'otPay': 0, 'deductions': 0, 'netPay': 0};
    }
    
    final staffType = _staffRecord!['staffType'] as String? ?? 'PERMANENT';
    final salary = (_staffRecord!['salary'] as num?)?.toDouble() ?? 0;
    final dailyWageRate = (_staffRecord!['dailyWageRate'] as num?)?.toDouble() ?? 0;
    final hourlyRate = (_staffRecord!['hourlyRate'] as num?)?.toDouble() ?? 0;
    
    final attendance = _salaryData!['attendance'] as Map<String, dynamic>;
    final daysPresent = (attendance['daysPresent'] as num?)?.toInt() ?? 0;
    final totalOvertime = (attendance['totalOvertime'] as num?)?.toDouble() ?? 0;
    final pendingAdvances = (_salaryData!['pendingAdvances'] as num?)?.toDouble() ?? 0;
    
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

  Future<void> _downloadPDF() async {
    if (_staffRecord == null || _salaryData == null) return;
    
    final payroll = _calculatePayroll();
    final firm = _salaryData!['firm'] as Map<String, dynamic>?;
    final attendance = _salaryData!['attendance'] as Map<String, dynamic>;
    final disbursement = _salaryData!['disbursement'] as Map<String, dynamic>?;
    
    final staffName = _staffRecord!['name'] as String;
    final staffRole = _staffRecord!['role'] as String? ?? '';
    
    final headers = ['Description', 'Amount'];
    final rows = <List<dynamic>>[
      ['--- EARNINGS ---', ''],
      ['Base Pay (${attendance['daysPresent']} days)', '₹${payroll['basePay']!.toStringAsFixed(0)}'],
      ['OT Pay (${(attendance['totalOvertime'] as num).toStringAsFixed(1)}h @ ${_otMultiplier}x)', '₹${payroll['otPay']!.toStringAsFixed(0)}'],
      ['', ''],
      ['--- DEDUCTIONS ---', ''],
      ['Advance Deduction', '₹${payroll['deductions']!.toStringAsFixed(0)}'],
      ['', ''],
      ['NET PAYABLE', '₹${payroll['netPay']!.toStringAsFixed(0)}'],
    ];
    
    if (disbursement != null && disbursement['status'] == 'PAID') {
      rows.add(['', '']);
      rows.add(['Payment Status', 'PAID']);
      rows.add(['Payment Mode', disbursement['paymentMode'] ?? '-']);
      rows.add(['Payment Date', disbursement['paidAt']?.toString().substring(0, 10) ?? '-']);
    }
    
    try {
      await ReportExportService().exportToPdf(
        title: 'Salary Slip - $_monthDisplay',
        subtitle: '$staffName${staffRole.isNotEmpty ? ' ($staffRole)' : ''}\n${firm?['name'] ?? 'Company'}',
        headers: headers,
        rows: rows,
        filename: 'salary_slip_${_monthYear}_$staffName.pdf',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salary slip saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payroll = _calculatePayroll();
    final attendance = (_salaryData?['attendance'] as Map<String, dynamic>?) ?? {};
    final disbursement = _salaryData?['disbursement'] as Map<String, dynamic>?;
    final isPaid = disbursement?['status'] == 'PAID';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Salary Slips'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _staffRecord == null
              ? _buildNoStaffRecord()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Month Selector
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                                  color: _selectedMonth.month == DateTime.now().month && 
                                         _selectedMonth.year == DateTime.now().year
                                      ? Colors.grey 
                                      : null,
                                ),
                                onPressed: _nextMonth,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Payment Status Banner
                      if (isPaid)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('PAID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                    Text(
                                      '${disbursement!['paymentMode'] ?? ''} • ${disbursement['paidAt']?.toString().substring(0, 10) ?? ''}',
                                      style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      if (!isPaid && (attendance['daysPresent'] ?? 0) > 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.hourglass_empty, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Text('Payment Pending', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      
                      // Net Pay Hero
                      Card(
                        color: Colors.teal.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text('Net Payable', style: TextStyle(fontSize: 14, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text(
                                '₹${payroll['netPay']!.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Earnings Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.add_circle, color: Colors.green.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  const Text('Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const Divider(),
                              _buildRow('Base Pay (${attendance['daysPresent'] ?? 0} days)', payroll['basePay']!, Colors.green),
                              _buildRow('OT Pay (${(attendance['totalOvertime'] as num? ?? 0).toStringAsFixed(1)}h)', payroll['otPay']!, Colors.orange),
                              const Divider(),
                              _buildRow('Total Earnings', payroll['basePay']! + payroll['otPay']!, Colors.green, bold: true),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Deductions Section
                      if (payroll['deductions']! > 0)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.remove_circle, color: Colors.red.shade600, size: 20),
                                    const SizedBox(width: 8),
                                    const Text('Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                const Divider(),
                                _buildRow('Advance Deduction', payroll['deductions']!, Colors.red),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      
                      // Download Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _downloadPDF,
                          icon: const Icon(Icons.download),
                          label: const Text('Download Salary Slip'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // History Section
                      if (_history.isNotEmpty) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final item = _history[index];
                            final monthYear = item['monthYear'] as String;
                            final netPay = (item['netPay'] as num?)?.toDouble() ?? 0;
                            final status = item['status'] as String? ?? 'PENDING';
                            final paidAt = item['paidAt'] as String?;
                            
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: status == 'PAID' ? Colors.green.shade100 : Colors.orange.shade100,
                                  child: Icon(
                                    status == 'PAID' ? Icons.check : Icons.hourglass_empty,
                                    color: status == 'PAID' ? Colors.green : Colors.orange,
                                    size: 20,
                                  ),
                                ),
                                title: Text(_formatMonthYear(monthYear)),
                                subtitle: Text(status == 'PAID' && paidAt != null 
                                    ? 'Paid on ${paidAt.substring(0, 10)}' 
                                    : status),
                                trailing: Text(
                                  '₹${netPay.toStringAsFixed(0)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedMonth = DateTime(
                                      int.parse(monthYear.split('-')[0]),
                                      int.parse(monthYear.split('-')[1]),
                                    );
                                  });
                                  _loadData();
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  String _formatMonthYear(String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length == 2) {
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMMM yyyy').format(dt);
    }
    return monthYear;
  }

  Widget _buildNoStaffRecord() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No Staff Record Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Your mobile is not linked to a staff record.', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildRow(String label, double amount, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14),
          ),
        ],
      ),
    );
  }
}
