import '../db/database_helper.dart';

class AnalyticsService {
  final _db = DatabaseHelper();

  // 1. Get Monthly Sales (Last 6 months)
  Future<List<Map<String, dynamic>>> getMonthlySales(String firmId) async {
    final db = await _db.database;
    // Query orders table, group by month
    // Note: SQLite doesn't have easy date formatting, so we might fetch and aggregate in Dart
    // Or use strftime if available (standard in sqflite)
    final result = await db.rawQuery('''
      SELECT 
        strftime('%Y-%m', date) as month, 
        SUM(finalAmount) as total 
      FROM orders 
      WHERE firmId = ? AND isCancelled = 0 
      GROUP BY month 
      ORDER BY month DESC 
      LIMIT 6
    ''', [firmId]);
    return result;
  }

  // 2. Get Top 5 Selling Items (from dishes table)
  Future<List<Map<String, dynamic>>> getTopItems(String firmId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT 
        dishName, 
        COUNT(*) as count,
        SUM(pricePerPlate * pax) as revenue
      FROM dishes 
      WHERE firmId = ? 
      GROUP BY dishName 
      ORDER BY count DESC 
      LIMIT 5
    ''', [firmId]);
    return result;
  }

  // 3. Get Expense Breakdown (from finance table)
  Future<List<Map<String, dynamic>>> getExpenseBreakdown(String firmId, String month) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT 
        category, 
        SUM(amount) as total 
      FROM finance 
      WHERE firmId = ? AND type = 'EXPENSE' AND strftime('%Y-%m', date) = ?
      GROUP BY category
    ''', [firmId, month]);
    return result;
  }

  // 4. Menu Engineering Analysis (BCG Matrix)
  Future<Map<String, List<String>>> getMenuAnalysis(String firmId) async {
    final db = await _db.database;
    final dishes = await db.rawQuery('''
      SELECT 
        dishName, 
        COUNT(*) as popularity,
        AVG(pricePerPlate) as avgPrice,
        SUM(pricePerPlate * pax) as totalRevenue
      FROM dishes 
      WHERE firmId = ? 
      GROUP BY dishName
    ''', [firmId]);

    if (dishes.isEmpty) {
      return {'Stars': [], 'Plowhorses': [], 'Puzzles': [], 'Dogs': []};
    }

    // Calculate Averages for classification
    double totalPop = 0;
    double totalRev = 0;
    for (var d in dishes) {
      totalPop += (d['popularity'] as num).toDouble();
      totalRev += (d['totalRevenue'] as num).toDouble();
    }
    double avgPop = totalPop / dishes.length;
    double avgRev = totalRev / dishes.length;

    List<String> stars = [];
    List<String> plowhorses = [];
    List<String> puzzles = [];
    List<String> dogs = [];

    for (var d in dishes) {
      final name = d['dishName']?.toString() ?? 'Unknown';
      final pop = (d['popularity'] as num).toDouble();
      final rev = (d['totalRevenue'] as num).toDouble();

      if (pop >= avgPop && rev >= avgRev) {
        stars.add(name);
      } else if (pop >= avgPop && rev < avgRev) {
        plowhorses.add(name);
      } else if (pop < avgPop && rev >= avgRev) {
        puzzles.add(name);
      } else {
        dogs.add(name);
      }
    }

    return {
      'Stars': stars,
      'Plowhorses': plowhorses,
      'Puzzles': puzzles,
      'Dogs': dogs,
    };
  }

  // 5. Narrative Insights Generation
  Future<String> getNarrativeInsights(String firmId) async {
    final sales = await getMonthlySales(firmId);
    if (sales.length < 2) return "Gathering data for AI narrative. Welcome to RuchiServ Analytics!";
    
    final current = (sales[0]['total'] as num?)?.toDouble() ?? 0.0;
    final previous = (sales[1]['total'] as num?)?.toDouble() ?? 0.0;
    final growth = previous > 0 ? ((current - previous) / previous * 100) : 0.0;
    
    String direction = growth >= 0 ? "increase" : "dip";
    return "Your revenue saw a ${growth.abs().toStringAsFixed(1)}% $direction this month compared to the previous period. "
           "Focusing on high-margin dishes identified in your BCG Matrix could boost your net profit by another 10% next month.";
  }
}
