import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../db/database_helper.dart';
import '../core/app_theme.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class AuditReportScreen extends StatefulWidget {
  const AuditReportScreen({super.key});

  @override
  State<AuditReportScreen> createState() => _AuditReportScreenState();
}

class _AuditReportScreenState extends State<AuditReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  
  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _userIdController = TextEditingController();
  String _selectedTable = 'All';
  final List<String> _tables = ['All', 'orders', 'dishes', 'users', 'firms'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final sp = await SharedPreferences.getInstance();
      final firmId = sp.getString('last_firm') ?? 'default_firm';
      
      
      final userId = _userIdController.text.trim().isEmpty ? null : _userIdController.text.trim();
      final tableName = _selectedTable == 'All' ? null : _selectedTable;
      
      final logs = await DatabaseHelper().getAuditLogs(
        firmId: firmId,
        userId: userId,
        tableName: tableName,
      );

      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading logs: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _loadLogs();
    }
  }

  Future<void> _exportCsv() async {
    // Web export not supported yet due to file system limitations
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV Export not supported on Web yet')),
      );
      return;
    }

    try {
      if (_logs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noLogsExport)),
        );
        return;
      }

      // Create CSV data
      List<List<dynamic>> rows = [];
      // Header
      rows.add([
        'ID', 'Timestamp', 'Action', 'Table', 'Record ID', 
        'User ID', 'Firm ID', 'Changed Fields', 'Before', 'After'
      ]);
      
      // Data
      for (var log in _logs) {
        rows.add([
          log['id'],
          log['timestamp'],
          log['action'],
          log['table_name'],
          log['record_id'],
          log['user_id'],
          log['firm_id'],
          log['changed_fields'],
          log['before_value'],
          log['after_value'],
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      
      // Save to file
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/audit_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      // Share file
      await Share.shareXFiles([XFile(path)], text: 'Audit Report');
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.exportFailed(e)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: AppLocalizations.of(context)!.export,
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(true),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(_startDate == null 
                            ? AppLocalizations.of(context)!.startDate 
                            : DateFormat('yyyy-MM-dd').format(_startDate!)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(false),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(_endDate == null 
                            ? AppLocalizations.of(context)!.endDate 
                            : DateFormat('yyyy-MM-dd').format(_endDate!)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _userIdController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.userIdLabel,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _loadLogs(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedTable,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.tableLabel,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          items: _tables.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedTable = val);
                              _loadLogs();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _loadLogs,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Logs List
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
                ? Center(child: Text(AppLocalizations.of(context)!.noAuditLogs))
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final date = DateTime.parse(log['timestamp']);
                      final action = log['action'];
                      final color = action == 'INSERT' ? Colors.green 
                        : action == 'UPDATE' ? Colors.orange 
                        : Colors.red;
                        
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.1),
                            child: Text(action[0], style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                          ),
                          title: Text('${log['table_name']} #${log['record_id']}'),
                          subtitle: Text(
                            '${DateFormat('MMM d, HH:mm').format(date)} • ${log['user_id']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (log['changed_fields'] != null && log['changed_fields'].toString().isNotEmpty)
                                    Text(AppLocalizations.of(context)!.changedFields(log['changed_fields'].toString()), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  if (log['before_value'] != null)
                                    Text(AppLocalizations.of(context)!.beforeVal(log['before_value'].toString()), style: const TextStyle(fontFamily: 'Courier', fontSize: 10)),
                                  if (log['after_value'] != null)
                                    Text(AppLocalizations.of(context)!.afterVal(log['after_value'].toString()), style: const TextStyle(fontFamily: 'Courier', fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
