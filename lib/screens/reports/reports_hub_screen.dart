import 'package:flutter/material.dart';
import 'finance_reports_screen.dart';
import 'utensil_report_screen.dart';
// import 'sales_reports_screen.dart';
// import 'kitchen_reports_screen.dart';
// import 'hr_reports_screen.dart';

class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Module", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildReportTile(
                  context,
                  "Finance",
                  Icons.pie_chart,
                  Colors.green,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceReportsScreen())),
                ),
                _buildReportTile(
                  context,
                  "Sales",
                  Icons.bar_chart,
                  Colors.blue,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming Soon...')));
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportsScreen()));
                  },
                ),
                _buildReportTile(
                  context,
                  "Utensils",
                  Icons.restaurant,
                  Colors.teal,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UtensilReportScreen())),
                ),
                _buildReportTile(
                  context,
                  "HR & Payroll",
                  Icons.people,
                  Colors.purple,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming Soon...')));
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => const HrReportsScreen()));
                  },
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
