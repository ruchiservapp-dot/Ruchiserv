// MODULE: DRIVER EARNINGS SCREEN (v34)
// Features: Trip history, km tracking, earnings summary, date filters, export
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import 'report_preview_page.dart';

class DriverEarningsScreen extends StatefulWidget {
  final int driverId;
  
  const DriverEarningsScreen({super.key, required this.driverId});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  
  List<Map<String, dynamic>> _trips = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final db = await DatabaseHelper().database;
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    
    // Get completed trips with earnings
    final trips = await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date, o.time, o.totalPax
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      WHERE d.driverId = ? 
        AND DATE(d.dispatchTime) BETWEEN ? AND ?
        AND d.dispatchStatus IN ('DELIVERED', 'COMPLETED', 'RETURNING')
      ORDER BY d.dispatchTime DESC
    ''', [widget.driverId, startStr, endStr]);
    
    // Get summary
    final summary = await db.rawQuery('''
      SELECT 
        COUNT(*) as tripCount,
        COALESCE(SUM(kmForward), 0) as totalKmForward,
        COALESCE(SUM(kmReturn), 0) as totalKmReturn,
        COALESCE(SUM(driverShare), 0) as totalEarnings,
        SUM(CASE WHEN isPaid = 1 THEN driverShare ELSE 0 END) as paidAmount,
        SUM(CASE WHEN isPaid = 0 THEN driverShare ELSE 0 END) as pendingAmount
      FROM dispatches
      WHERE driverId = ? 
        AND DATE(dispatchTime) BETWEEN ? AND ?
        AND dispatchStatus IN ('DELIVERED', 'COMPLETED', 'RETURNING')
    ''', [widget.driverId, startStr, endStr]);
    
    setState(() {
      _trips = List<Map<String, dynamic>>.from(trips);
      _summary = summary.isNotEmpty ? Map<String, dynamic>.from(summary.first) : {};
      _isLoading = false;
    });
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  void _exportReport() {
    final headers = ['Date', 'Customer', 'Location', 'Forward KM', 'Return KM', 'Earnings', 'Paid'];
    final rows = _trips.map((t) => [
      t['date'] ?? '',
      t['customerName'] ?? '',
      t['location'] ?? '',
      (t['kmForward'] as num?)?.toStringAsFixed(1) ?? '0',
      (t['kmReturn'] as num?)?.toStringAsFixed(1) ?? '0',
      '₹${(t['driverShare'] as num?)?.toStringAsFixed(0) ?? '0'}',
      t['isPaid'] == 1 ? 'Yes' : 'No',
    ]).toList();
    
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReportPreviewPage(
        title: 'Driver Earnings Report',
        subtitle: '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}',
        headers: headers,
        rows: rows,
        accentColor: Colors.green,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final totalKm = ((_summary['totalKmForward'] as num?)?.toDouble() ?? 0) + 
                    ((_summary['totalKmReturn'] as num?)?.toDouble() ?? 0);
    final totalEarnings = (_summary['totalEarnings'] as num?)?.toDouble() ?? 0;
    final paidAmount = (_summary['paidAmount'] as num?)?.toDouble() ?? 0;
    final pendingAmount = (_summary['pendingAmount'] as num?)?.toDouble() ?? 0;
    final tripCount = (_summary['tripCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Earnings'),
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportReport, tooltip: 'Export'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date Filter
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.green.shade50,
                  child: InkWell(
                    onTap: _pickDateRange,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: Colors.green),
                      ],
                    ),
                  ),
                ),
                
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: _buildSummaryCard('Total Earnings', '₹${totalEarnings.toStringAsFixed(0)}', Colors.green, Icons.currency_rupee)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSummaryCard('Total KM', '${totalKm.toStringAsFixed(1)} km', Colors.blue, Icons.route)),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(child: _buildSummaryCard('Trips', '$tripCount', Colors.purple, Icons.local_shipping)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSummaryCard('Pending', '₹${pendingAmount.toStringAsFixed(0)}', Colors.orange, Icons.pending)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Trip History
                Expanded(
                  child: _trips.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No trips in this period', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _trips.length,
                          itemBuilder: (ctx, i) => _buildTripCard(_trips[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final date = trip['date'] ?? '';
    final customer = trip['customerName'] ?? 'Customer';
    final location = trip['location'] ?? 'N/A';
    final kmForward = (trip['kmForward'] as num?)?.toDouble() ?? 0;
    final kmReturn = (trip['kmReturn'] as num?)?.toDouble() ?? 0;
    final earnings = (trip['driverShare'] as num?)?.toDouble() ?? 0;
    final isPaid = trip['isPaid'] == 1;
    
    String dateLabel = date;
    try {
      final dt = DateTime.parse(date);
      dateLabel = DateFormat('MMM d').format(dt);
    } catch (_) {}
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Could show trip details
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(dateLabel, style: TextStyle(color: Colors.indigo.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  Text('₹${earnings.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isPaid ? 'PAID' : 'PENDING',
                      style: TextStyle(
                        color: isPaid ? Colors.green.shade800 : Colors.orange.shade800,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(customer, style: const TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(location, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _kmChip('Forward', kmForward, Icons.arrow_forward),
                  const SizedBox(width: 8),
                  _kmChip('Return', kmReturn, Icons.arrow_back),
                  const SizedBox(width: 8),
                  _kmChip('Total', kmForward + kmReturn, Icons.route),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kmChip(String label, double km, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text('${km.toStringAsFixed(1)} km', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
        ],
      ),
    );
  }
}
