// lib/services/report_export_service.dart
// Export service for Reports - Excel, PDF, Share
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReportExportService {
  static final ReportExportService _instance = ReportExportService._internal();
  factory ReportExportService() => _instance;
  ReportExportService._internal();

  /// Export data to Excel file
  Future<File?> exportToExcel({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String? filename,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Report'];
      
      // Add title row
      sheet.appendRow([TextCellValue(title)]);
      sheet.appendRow([]); // Empty row
      
      // Add headers
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      
      // Add data rows
      for (var row in rows) {
        sheet.appendRow(row.map((cell) {
          if (cell == null) return TextCellValue('');
          if (cell is num) return DoubleCellValue(cell.toDouble());
          return TextCellValue(cell.toString());
        }).toList());
      }
      
      // Style headers
      final headerRow = sheet.row(2);
      for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#4CAF50'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
      }
      
      // Auto-fit columns (basic)
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 20);
      }
      
      // Save file
      final bytes = excel.encode();
      if (bytes == null) return null;
      
      final dir = await getApplicationDocumentsDirectory();
      final fname = filename ?? 'report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fname');
      await file.writeAsBytes(bytes);
      
      return file;
    } catch (e) {
      print('Excel export error: $e');
      return null;
    }
  }

  /// Load a Unicode-compatible font (Cached by printing package)
  Future<pw.Font> _loadFont() async {
    try {
      // NotoSans covers most standard Unicode including Rupee sign
      return await PdfGoogleFonts.notoSansRegular();
    } catch (e) {
      print('Font load error: $e. Falling back to standard.');
      return pw.Font.helvetica(); // Fallback (might still fail for symbols)
    }
  }

  /// Export data to PDF
  Future<File?> exportToPdf({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String? filename,
    String? subtitle,
  }) async {
    try {
      final font = await _loadFont();
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: font),
      );
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              if (subtitle != null)
                pw.Text(subtitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              pw.SizedBox(height: 10),
              pw.Divider(),
            ],
          ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows.map((r) => r.map((c) => c?.toString() ?? '').toList()).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),
          ],
        ),
      );
      
      final bytes = await pdf.save();
      final dir = await getApplicationDocumentsDirectory();
      final fname = filename ?? 'report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fname');
      await file.writeAsBytes(bytes);
      
      return file;
    } catch (e) {
      print('PDF export error: $e');
      return null;
    }
  }

  /// Preview PDF before saving/sharing
  Future<void> previewPdf({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String? subtitle,
  }) async {
    try {
      final font = await _loadFont();
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: font),
      );
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              if (subtitle != null)
                pw.Text(subtitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              pw.SizedBox(height: 10),
              pw.Divider(),
            ],
          ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows.map((r) => r.map((c) => c?.toString() ?? '').toList()).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),
          ],
        ),
      );
      
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      print('PDF preview error: $e');
    }
  }

  /// Share file via system share sheet
  Future<void> shareFile(File file, {String? subject}) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject ?? 'Report Export',
      );
    } catch (e) {
      print('Share error: $e');
    }
  }

  /// Quick share - export to PDF and share immediately
  Future<void> quickSharePdf({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String? subtitle,
  }) async {
    final file = await exportToPdf(
      title: title,
      headers: headers,
      rows: rows,
      subtitle: subtitle,
    );
    if (file != null) {
      await shareFile(file, subject: title);
    }
  }

  /// Quick share - export to Excel and share immediately
  Future<void> quickShareExcel({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    final file = await exportToExcel(
      title: title,
      headers: headers,
      rows: rows,
    );
    if (file != null) {
      await shareFile(file, subject: title);
    }
  }
}
