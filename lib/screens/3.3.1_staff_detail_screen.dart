// MODULE: STAFF DETAIL (LOCKED) - DO NOT EDIT WITHOUT AUTHORIZATION
// Last Locked: 2025-12-08 | Features: Profile View/Edit, Bank Details, Advances, Photo Upload, Attendance History
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class StaffDetailScreen extends StatefulWidget {
  final int? staffId;
  
  const StaffDetailScreen({super.key, this.staffId});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isNew = true;
  String? _firmId;
  
  // Controllers
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _salaryController = TextEditingController(text: '0');
  final _dailyWageController = TextEditingController(text: '0');
  final _hourlyRateController = TextEditingController(text: '0');
  final _addressController = TextEditingController();
  final _aadharController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  
  // Dropdown values
  String _staffType = 'PERMANENT';
  String _payoutFrequency = 'MONTHLY';
  
  // Photo
  String? _photoUrl;
  
  // Advances
  List<Map<String, dynamic>> _advances = [];
  
  // Attendance History
  List<Map<String, dynamic>> _attendanceHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.staffId != null ? 3 : 1, vsync: this);
    _isNew = widget.staffId == null;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _salaryController.dispose();
    _dailyWageController.dispose();
    _hourlyRateController.dispose();
    _addressController.dispose();
    _aadharController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _bankNameController.dispose();
    _emergencyContactController.dispose();
    _emergencyNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final sp = await SharedPreferences.getInstance();
    _firmId = sp.getString('last_firm');
    
    if (widget.staffId != null) {
      final db = await DatabaseHelper().database;
      
      // Load staff details
      final staffList = await db.query('staff', where: 'id = ?', whereArgs: [widget.staffId]);
      if (staffList.isNotEmpty) {
        final staff = staffList.first;
        _nameController.text = staff['name']?.toString() ?? '';
        _roleController.text = staff['role']?.toString() ?? '';
        _mobileController.text = staff['mobile']?.toString() ?? '';
        _emailController.text = staff['email']?.toString() ?? '';
        _salaryController.text = (staff['salary'] ?? 0).toString();
        _dailyWageController.text = (staff['dailyWageRate'] ?? 0).toString();
        _hourlyRateController.text = (staff['hourlyRate'] ?? 0).toString();
        _addressController.text = staff['address']?.toString() ?? '';
        _aadharController.text = staff['aadharNumber']?.toString() ?? '';
        _bankAccountController.text = staff['bankAccountNo']?.toString() ?? '';
        _bankIfscController.text = staff['bankIfsc']?.toString() ?? '';
        _bankNameController.text = staff['bankName']?.toString() ?? '';
        _emergencyContactController.text = staff['emergencyContact']?.toString() ?? '';
        _emergencyNameController.text = staff['emergencyContactName']?.toString() ?? '';
        _staffType = staff['staffType']?.toString() ?? 'PERMANENT';
        _payoutFrequency = staff['payoutFrequency']?.toString() ?? 'MONTHLY';
        _photoUrl = staff['photoUrl']?.toString();
      }
      
      // Load advances
      _advances = await db.query(
        'staff_advances',
        where: 'staffId = ?',
        whereArgs: [widget.staffId],
        orderBy: 'advanceDate DESC',
      );
      
      // Load attendance history
      _attendanceHistory = await db.query(
        'attendance',
        where: 'staffId = ?',
        whereArgs: [widget.staffId],
        orderBy: 'date DESC',
        limit: 30,
      );
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final data = {
        'firmId': _firmId ?? 'DEFAULT',
        'name': _nameController.text.trim(),
        'role': _roleController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'email': _emailController.text.trim(),
        'salary': double.tryParse(_salaryController.text) ?? 0,
        'dailyWageRate': double.tryParse(_dailyWageController.text) ?? 0,
        'hourlyRate': double.tryParse(_hourlyRateController.text) ?? 0,
        'address': _addressController.text.trim(),
        'aadharNumber': _aadharController.text.trim(),
        'bankAccountNo': _bankAccountController.text.trim(),
        'bankIfsc': _bankIfscController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'emergencyContactName': _emergencyNameController.text.trim(),
        'staffType': _staffType,
        'payoutFrequency': _payoutFrequency,
        'photoUrl': _photoUrl,
        'isActive': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      final db = await DatabaseHelper().database;
      
      if (_isNew) {
        data['joinDate'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
        data['createdAt'] = DateTime.now().toIso8601String();
        await db.insert('staff', data);
      } else {
        await db.update('staff', data, where: 'id = ?', whereArgs: [widget.staffId]);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isNew ? AppLocalizations.of(context)!.staffAdded : AppLocalizations.of(context)!.staffUpdated), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
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

  Future<void> _addAdvance() async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.addAdvance),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.amountRupee, prefixText: '₹ '),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.add),
          ),
        ],
      ),
    );
    
    if (result == true && amountController.text.isNotEmpty) {
      final db = await DatabaseHelper().database;
      await db.insert('staff_advances', {
        'staffId': widget.staffId,
        'amount': double.tryParse(amountController.text) ?? 0,
        'advanceDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'reason': reasonController.text,
        'deductedFromPayroll': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
      _loadData();
    }
  }

  Future<void> _deleteStaff() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteStaff),
        content: Text(AppLocalizations.of(context)!.deleteStaffConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final db = await DatabaseHelper().database;
      await db.delete('staff', where: 'id = ?', whereArgs: [widget.staffId]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.staffDeleted), backgroundColor: Colors.red),
        );
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.selectPhoto),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(AppLocalizations.of(context)!.camera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(AppLocalizations.of(context)!.gallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    
    if (source == null) return;
    
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, maxWidth: 500, maxHeight: 500);
      
      if (image == null) return;
      
      // Web: Use network path/blob directly, skip local file saving
      if (kIsWeb) {
        setState(() => _photoUrl = image.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.photoSelectedWeb), backgroundColor: Colors.green),
        );
        return;
      }
      
      // Save to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'staff_${widget.staffId ?? DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = path.join(appDir.path, 'staff_photos', fileName);
      
      // Create directory if not exists
      final photoDir = Directory(path.join(appDir.path, 'staff_photos'));
      if (!await photoDir.exists()) {
        await photoDir.create(recursive: true);
      }
      
      // Copy file
      final savedFile = await File(image.path).copy(savedPath);
      
      setState(() => _photoUrl = savedFile.path);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.photoUpdated), backgroundColor: Colors.green),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? AppLocalizations.of(context)!.addStaff : AppLocalizations.of(context)!.staffDetails),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteStaff,
            ),
        ],
        bottom: widget.staffId != null
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Profile'),
                  Tab(text: 'Advances'),
                  Tab(text: 'Attendance'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.staffId != null
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProfileTab(),
                    _buildAdvancesTab(),
                    _buildAttendanceTab(),
                  ],
                )
              : _buildProfileTab(),
    );
  }

  Widget _buildProfileTab() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Photo Section
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _photoUrl != null && File(_photoUrl!).existsSync()
                        ? FileImage(File(_photoUrl!))
                        : null,
                    child: _photoUrl == null || !File(_photoUrl!).existsSync()
                        ? Icon(Icons.person, size: 50, color: Colors.grey.shade600)
                        : null,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              AppLocalizations.of(context)!.tapToPhoto(_photoUrl != null ? 'change' : 'add'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),
          
          // Basic Info Section
          Text(AppLocalizations.of(context)!.basicInfo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.fullName, border: const OutlineInputBorder()),
            validator: (v) => v?.isEmpty == true ? AppLocalizations.of(context)!.requiredField : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _roleController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.roleDesignation, border: const OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _staffType,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.staffType, border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'PERMANENT', child: Text(AppLocalizations.of(context)!.permanent)),
                    DropdownMenuItem(value: 'DAILY_WAGE', child: Text(AppLocalizations.of(context)!.dailyWage)),
                    DropdownMenuItem(value: 'CONTRACTOR', child: Text(AppLocalizations.of(context)!.contractor)),
                  ],
                  onChanged: (v) => setState(() => _staffType = v ?? 'PERMANENT'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _mobileController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.mobileNumber, border: const OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.email, border: const OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context)!.salaryRates, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _salaryController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.monthlySalary, border: const OutlineInputBorder(), prefixText: '₹ '),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _payoutFrequency,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.payoutFrequency, border: const OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                    DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                    DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                  ],
                  onChanged: (v) => setState(() => _payoutFrequency = v ?? 'MONTHLY'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dailyWageController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.dailyWageLabel, border: const OutlineInputBorder(), prefixText: '₹ '),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _hourlyRateController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.hourlyRate, border: const OutlineInputBorder(), prefixText: '₹ '),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context)!.bankIdDetails, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bankNameController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.bankName, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _bankAccountController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.accountNumber, border: const OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _bankIfscController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.ifscCode, border: const OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _aadharController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.aadharNumber, border: const OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context)!.emergencyContact, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emergencyNameController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.contactName, border: const OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _emergencyContactController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.contactNumber, border: const OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.address, border: const OutlineInputBorder()),
            maxLines: 2,
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isNew ? AppLocalizations.of(context)!.addStaffBtn : AppLocalizations.of(context)!.saveChanges, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancesTab() {
    final totalAdvances = _advances.fold<double>(0, (sum, a) => sum + ((a['amount'] as num?) ?? 0));
    final pendingAdvances = _advances.where((a) => a['deductedFromPayroll'] != 1).fold<double>(0, (sum, a) => sum + ((a['amount'] as num?) ?? 0));
    
    return Column(
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('₹${totalAdvances.toStringAsFixed(0)}', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(AppLocalizations.of(context)!.totalAdvances, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Column(
                children: [
                  Text('₹${pendingAdvances.toStringAsFixed(0)}', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                  Text(AppLocalizations.of(context)!.pendingDeduction, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        
        // Add Advance Button
        Padding(
          padding: const EdgeInsets.all(8),
          child: ElevatedButton.icon(
            onPressed: _addAdvance,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.addAdvance),
          ),
        ),
        
        // Advances List
        Expanded(
          child: _advances.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noAdvances))
              : ListView.builder(
                  itemCount: _advances.length,
                  itemBuilder: (context, index) {
                    final advance = _advances[index];
                    final isDeducted = advance['deductedFromPayroll'] == 1;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDeducted ? Colors.green : Colors.orange,
                          child: Icon(
                            isDeducted ? Icons.check : Icons.pending,
                            color: Colors.white,
                          ),
                        ),
                        title: Text('₹${(advance['amount'] as num).toStringAsFixed(0)}'),
                        subtitle: Text('${advance['advanceDate']}${advance['reason'] != null && advance['reason'].isNotEmpty ? ' - ${advance['reason']}' : ''}'),
                        trailing: isDeducted
                            ? Chip(label: Text(AppLocalizations.of(context)!.deducted, style: const TextStyle(fontSize: 10)))
                            : Chip(label: Text(AppLocalizations.of(context)!.pending, style: const TextStyle(fontSize: 10)), backgroundColor: Colors.orange),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTab() {
    final totalDays = _attendanceHistory.length;
    final totalHours = _attendanceHistory.fold<double>(0, (sum, a) => sum + ((a['hoursWorked'] as num?) ?? 0));
    final totalOT = _attendanceHistory.fold<double>(0, (sum, a) => sum + ((a['overtime'] as num?) ?? 0));
    
    return Column(
      children: [
        // Stats
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('$totalDays', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('Days (30)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Column(
                children: [
                  Text('${totalHours.toStringAsFixed(1)}', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const Text('Total Hours', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Column(
                children: [
                  Text('${totalOT.toStringAsFixed(1)}', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const Text('OT Hours', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        
        // Attendance List
        Expanded(
          child: _attendanceHistory.isEmpty
              ? const Center(child: Text('No attendance records'))
              : ListView.builder(
                  itemCount: _attendanceHistory.length,
                  itemBuilder: (context, index) {
                    final record = _attendanceHistory[index];
                    final isWithinGeoFence = record['isWithinGeoFence'] == 1;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isWithinGeoFence ? Colors.green : Colors.orange,
                          child: Text(
                            DateFormat('dd').format(DateTime.parse(record['date'])),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(DateFormat('EEEE, MMM d').format(DateTime.parse(record['date']))),
                        subtitle: Text(
                          'In: ${record['punchInTime'] ?? '-'} | Out: ${record['punchOutTime'] ?? '-'}'
                          '\n${((record['hoursWorked'] as num?) ?? 0).toStringAsFixed(1)} hrs'
                          '${((record['overtime'] as num?) ?? 0) > 0 ? ' (+${((record['overtime'] as num?) ?? 0).toStringAsFixed(1)} OT)' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: Icon(
                          isWithinGeoFence ? Icons.location_on : Icons.location_off,
                          color: isWithinGeoFence ? Colors.green : Colors.orange,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
