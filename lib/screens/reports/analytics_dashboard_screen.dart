import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../widgets/chart_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  String? _firmId;
  bool _isLoading = true;

  // Data Holders
  String _narrative = "Analyzing your business data...";
  Map<String, List<String>> _menuAnalysis = {'Stars': [], 'Plowhorses': [], 'Puzzles': [], 'Dogs': []};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sp = await SharedPreferences.getInstance();
    _firmId = sp.getString('last_firm');
    
    if (_firmId != null) {
      final narrative = await _analyticsService.getNarrativeInsights(_firmId!);
      final analysis = await _analyticsService.getMenuAnalysis(_firmId!);

      if (mounted) {
        setState(() {
          _narrative = narrative;
          _menuAnalysis = analysis;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNarrativeInsights(),
            const SizedBox(height: 24),
            _buildRevenueForecast(),
            const SizedBox(height: 24),
            _buildMenuEngineeringSummary(),
            const SizedBox(height: 24),
            _buildAnomalyAlerts(),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrativeInsights() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF0D47A1).withValues(alpha: 0.3), const Color(0xFF1E88E5).withValues(alpha: 0.1)]
            : [const Color(0xFFE3F2FD), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text('AI Summary', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blue.shade200 : Colors.blue.shade900)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_narrative,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueForecast() {
    return _buildHubCard(
      title: 'Demand & Revenue Forecast',
      subtitle: 'Predicting the next 30 days',
      icon: Icons.timeline,
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.query_stats, size: 48, color: AppColors.primary.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              const Text('Predictive Engine Warming Up...', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuEngineeringSummary() {
    return _buildHubCard(
      title: 'Menu Engineering (BCG Matrix)',
      subtitle: 'Star performers vs. Underperformers',
      icon: Icons.restaurant_menu,
      child: Column(
        children: [
          _buildMatrixRow('Stars (High Margin/Volume)', 
            _menuAnalysis['Stars']!.isEmpty ? 'No stars identified yet' : _menuAnalysis['Stars']!.join(', '), 
            Colors.green),
          _buildMatrixRow('Plowhorses (Low Margin/Vol)', 
            _menuAnalysis['Plowhorses']!.isEmpty ? 'No data' : _menuAnalysis['Plowhorses']!.join(', '), 
            Colors.orange),
          _buildMatrixRow('Puzzles (High Margin/Low Vol)', 
            _menuAnalysis['Puzzles']!.isEmpty ? 'No data' : _menuAnalysis['Puzzles']!.join(', '), 
            Colors.blue),
           _buildMatrixRow('Dogs (Review Necessary)', 
            _menuAnalysis['Dogs']!.isEmpty ? 'No data' : _menuAnalysis['Dogs']!.join(', '), 
            Colors.red),
        ],
      ),
    );
  }

  Widget _buildMatrixRow(String title, String items, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(width: 4, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(items, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyAlerts() {
    return _buildHubCard(
      title: 'Anomaly Detection',
      subtitle: 'Smart monitors for your business',
      icon: Icons.gpp_maybe,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'High Waste Alert: Your raw material spend on "Dairy" is 15% higher than average.',
                style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHubCard({required String title, required String subtitle, required IconData icon, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.grey.shade200, blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
