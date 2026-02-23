import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class SimpleLineChart extends StatelessWidget {
  final List<double> dataPoints;
  final List<String> xLabels;

  const SimpleLineChart({super.key, required this.dataPoints, required this.xLabels});

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) return const Center(child: Text("No Data"));
    
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < xLabels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(xLabels[index], style: const TextStyle(fontSize: 10)),
                  );
                }
                return const Text('');
              },
              interval: 1,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: dataPoints.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value);
            }).toList(),
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }
}

class SimplePieChart extends StatelessWidget {
  final Map<String, double> data;

  const SimplePieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text("No Data"));

    final List<Color> colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal
    ];

    int i = 0;
    return Row(
      children: [
        SizedBox(
          height: 200,
          width: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: data.entries.map((e) {
                final color = colors[i++ % colors.length];
                return PieChartSectionData(
                  color: color,
                  value: e.value,
                  title: '${(e.value / data.values.reduce((a, b) => a + b) * 100).toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.entries.map((e) {
               final index = data.keys.toList().indexOf(e.key);
               return Padding(
                 padding: const EdgeInsets.symmetric(vertical: 4.0),
                 child: Row(
                   children: [
                     Container(width: 12, height: 12, color: colors[index % colors.length]),
                     const SizedBox(width: 8),
                     Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                   ],
                 ),
               );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
