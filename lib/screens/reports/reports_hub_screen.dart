import 'package:flutter/material.dart';
import 'finance_reports_screen.dart';
import 'utensil_report_screen.dart';
import 'pl_report_screen.dart';
import 'event_profitability_screen.dart';
import 'balance_sheet_screen.dart';
import 'cash_flow_screen.dart';
import 'kpi_dashboard_screen.dart';
import '../../services/permission_service.dart';

class ReportsHubScreen extends StatefulWidget {
  const ReportsHubScreen({super.key});

  @override
  State<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends State<ReportsHubScreen> {
  bool _canAccessFinanceReports = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final canAccess = await PermissionService.instance.canAccessFinanceReports();
    setState(() {
      _canAccessFinanceReports = canAccess;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Dashboard - Hero Section
                  if (_canAccessFinanceReports) ...[
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const KPIDashboardScreen()),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.dashboard, size: 32, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('KPI Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                  SizedBox(height: 4),
                                  Text('Revenue, Margin, Orders at a glance', style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Financial Reports Section
                  if (_canAccessFinanceReports) ...[
                    const Text("Financial Reports", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildReportTile(
                          context,
                          "Balance Sheet",
                          Icons.account_balance,
                          Colors.indigo,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BalanceSheetScreen())),
                        ),
                        _buildReportTile(
                          context,
                          "Cash Flow",
                          Icons.waterfall_chart,
                          Colors.teal,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashFlowScreen())),
                        ),
                        _buildReportTile(
                          context,
                          "P&L Report",
                          Icons.trending_up,
                          Colors.green,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PLReportScreen())),
                        ),
                        _buildReportTile(
                          context,
                          "Event Profit",
                          Icons.event_note,
                          Colors.purple,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventProfitabilityScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Operational Reports Section
                  const Text("Operational Reports", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      _buildReportTile(
                        context,
                        "Finance",
                        Icons.pie_chart,
                        Colors.blue,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceReportsScreen())),
                      ),
                      _buildReportTile(
                        context,
                        "Utensils",
                        Icons.restaurant,
                        Colors.orange,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UtensilReportScreen())),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReportTile(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
