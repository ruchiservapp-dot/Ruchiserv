import 'package:flutter/material.dart';
import '../db/local/local_db_helper.dart';

class SummaryScreen extends StatefulWidget {
  final DateTime date;
  const SummaryScreen({super.key, required this.date});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _dishSummary = [];

  @override
  void initState() {
    super.initState();
    _loadDishSummary();
  }

  Future<void> _loadDishSummary() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final dateString = widget.date.toIso8601String().split('T').first;
      final data = await LocalDbHelper.getDishesSummaryByDate(dateString);
      setState(() {
        _dishSummary = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load summary: $e';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading summary: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByMealType(List<Map<String, dynamic>> items) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var d in items) {
      final meal = (d['mealType'] ?? 'Snacks/Others') as String;
      (grouped[meal] ??= []).add(d);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = '${widget.date.day}/${widget.date.month}/${widget.date.year}';
    final grouped = _groupByMealType(_dishSummary);

    return Scaffold(
      appBar: AppBar(title: Text('Summary - $formattedDate'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadDishSummary,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _dishSummary.isEmpty
                  ? const Center(child: Text('No dishes found for this date'))
                  : RefreshIndicator(
                      onRefresh: _loadDishSummary,
                      child: ListView(
                        children: [
                          for (final meal in ['Breakfast', 'Lunch', 'Dinner', 'Snacks/Others'])
                            if (grouped[meal]?.isNotEmpty ?? false)
                              _MealGroupCard(meal: meal, dishes: grouped[meal]!),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }
}

class _MealGroupCard extends StatelessWidget {
  final String meal;
  final List<Map<String, dynamic>> dishes;
  const _MealGroupCard({required this.meal, required this.dishes});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meal, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final d in dishes)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(d['name']?.toString() ?? 'Unnamed dish'),
              subtitle: Text('${d['foodType'] ?? 'Veg'}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Pax: ${d['totalPax'] ?? 0}'),
                  Text('₹${d['totalCost'] ?? 0}'),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}
