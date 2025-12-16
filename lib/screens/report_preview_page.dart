// Report Preview Page - Shows report data before export
// Created: 2025-12-15 | Shows full report preview with export options
import 'package:flutter/material.dart';
import '../services/report_export_service.dart';

class ReportPreviewPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> headers;
  final List<List<dynamic>> rows;
  final Color accentColor;

  const ReportPreviewPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.headers,
    required this.rows,
    this.accentColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final exportService = ReportExportService();

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        actions: [
          // Excel Export Button
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Export to Excel',
            onPressed: () async {
              _showLoadingDialog(context, 'Generating Excel...');
              final file = await exportService.exportToExcel(
                title: '$title\n$subtitle',
                headers: headers,
                rows: rows,
              );
              Navigator.pop(context); // Close loading dialog
              if (file != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Excel opened: ${file.path.split('/').last}'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to export Excel'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          // PDF Export Button
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export to PDF',
            onPressed: () async {
              _showLoadingDialog(context, 'Generating PDF...');
              final success = await exportService.previewPdf(
                title: title,
                headers: headers,
                rows: rows,
                subtitle: subtitle,
              );
              Navigator.pop(context); // Close loading dialog
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to generate PDF'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          // Share/Email Button
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share via Email',
            onPressed: () async {
              _showLoadingDialog(context, 'Preparing to share...');
              await exportService.quickSharePdf(
                title: title,
                headers: headers,
                rows: rows,
                subtitle: subtitle,
              );
              Navigator.pop(context); // Close loading dialog
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Info Header
          Container(
            width: double.infinity,
            color: accentColor.withOpacity(0.1),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${rows.length} rows',
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${headers.length} columns',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Export Options Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use the buttons above to export this report',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Data Table
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_rows_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No data to preview',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          accentColor.withOpacity(0.1),
                        ),
                        headingTextStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          fontSize: 13,
                        ),
                        dataTextStyle: const TextStyle(fontSize: 12),
                        columnSpacing: 24,
                        columns: headers
                            .map((h) => DataColumn(
                                  label: Text(h),
                                ))
                            .toList(),
                        rows: rows
                            .map((row) => DataRow(
                                  cells: row
                                      .map((cell) => DataCell(
                                            Text(
                                              cell?.toString() ?? '',
                                              style: _getCellStyle(cell),
                                            ),
                                          ))
                                      .toList(),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      // Bottom Action Bar for quick access
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.table_chart, size: 18),
                label: const Text('Excel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade700),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  _showLoadingDialog(context, 'Generating Excel...');
                  final file = await exportService.exportToExcel(
                    title: '$title\n$subtitle',
                    headers: headers,
                    rows: rows,
                  );
                  Navigator.pop(context);
                  if (file != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Excel saved: ${file.path.split('/').last}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  _showLoadingDialog(context, 'Generating PDF...');
                  final success = await exportService.previewPdf(
                    title: title,
                    headers: headers,
                    rows: rows,
                    subtitle: subtitle,
                  );
                  Navigator.pop(context);
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to generate PDF'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.email, size: 18),
                label: const Text('Mail'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade700),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  _showLoadingDialog(context, 'Preparing email...');
                  await exportService.quickSharePdf(
                    title: title,
                    headers: headers,
                    rows: rows,
                    subtitle: subtitle,
                  );
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle? _getCellStyle(dynamic cell) {
    if (cell is num) {
      final str = cell.toString();
      if (str.contains('.') && str.length > 5) {
        return const TextStyle(fontSize: 12, fontFamily: 'monospace');
      }
    }
    return null;
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }
}
