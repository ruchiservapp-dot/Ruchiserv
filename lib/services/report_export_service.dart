// lib/services/report_export_service.dart
// Export service for Reports - Excel, PDF, Share
// UPDATED: 2025-12-14 - Opens files in default apps for preview before saving
import 'dart:async';
import 'dart:io';
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

  /// Open file in default system application
  /// On macOS: opens in Preview (PDF), Numbers/Excel (xlsx)
  /// User can then view and save using Cmd+S or File → Save As
  Future<bool> _openInDefaultApp(String filePath) async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('open', [filePath]);
        return result.exitCode == 0;
      } else if (Platform.isWindows) {
        final result = await Process.run('start', ['', filePath], runInShell: true);
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [filePath]);
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      print('❌ Failed to open file: $e');
      return false;
    }
  }

  /// Export data to Excel file and open in default app (Numbers/Excel)
  /// User can view the data and save to desired location using Cmd+S
  /// Returns the file if successful, null otherwise
  Future<File?> exportToExcel({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String? filename,
    bool openInApp = true, // Open in default app for viewing
  }) async {
    try {
      print('📊 Excel: Starting export...');
      
      // Validate data
      if (rows.isEmpty) {
        print('⚠️ Excel: No data to export');
        return null;
      }
      
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
      if (bytes == null) {
        print('❌ Excel: Failed to encode workbook');
        return null;
      }
      
      // Save to temp directory with readable filename
      final dir = await getTemporaryDirectory();
      final fname = filename ?? 'RuchiServ_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fname');
      await file.writeAsBytes(bytes);
      
      print('✅ Excel: File saved to ${file.path}');
      print('📊 Excel: ${rows.length} rows exported');
      
      // Open in default app (Numbers/Excel) so user can view and save
      if (openInApp) {
        print('📂 Excel: Opening in default app...');
        final opened = await _openInDefaultApp(file.path);
        if (!opened) {
          print('⚠️ Excel: Failed to open, falling back to share sheet...');
          await Share.shareXFiles([XFile(file.path)], subject: title);
        }
      }
      
      return file;
    } catch (e, stack) {
      print('❌ Excel export error: $e');
      print('Stack: $stack');
      return null;
    }
  }

  /// Load a Unicode-compatible font with timeout and fallback
  pw.Font? _cachedFont;
  bool _useFallbackFont = false;
  
  Future<pw.Font> _loadFont() async {
    // Return cached font if available
    if (_cachedFont != null) return _cachedFont!;
    
    try {
      // Try loading Google Font with a 3-second timeout (reduced from 5)
      print('📄 PDF: Loading font from Google Fonts...');
      final font = await PdfGoogleFonts.notoSansRegular()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        print('⚠️ PDF: Font loading timed out, using fallback');
        throw TimeoutException('Font download timed out');
      });
      _cachedFont = font;
      print('✅ PDF: Font loaded successfully');
      return font;
    } catch (e) {
      print('⚠️ PDF: Font load error: $e. Using Helvetica fallback.');
      _useFallbackFont = true;
      _cachedFont = pw.Font.helvetica();
      return _cachedFont!;
    }
  }
  
  /// Sanitize text for Helvetica font (replace unsupported characters)
  String _sanitizeForFallbackFont(String text) {
    if (!_useFallbackFont) return text;
    // Replace Rupee symbol with Rs. for fonts that don't support it
    return text.replaceAll('₹', 'Rs.');
  }

  /// Export data to PDF file
  Future<File?> exportToPdf({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String? filename,
    String? subtitle,
  }) async {
    try {
      print('📄 PDF: Starting export...');
      
      // Validate data
      if (rows.isEmpty) {
        print('⚠️ PDF: No data to export');
        return null;
      }
      
      final font = await _loadFont();
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: font),
      );
      
      // Sanitize text if using fallback font
      final sanitizedTitle = _sanitizeForFallbackFont(title);
      final sanitizedSubtitle = subtitle != null ? _sanitizeForFallbackFont(subtitle) : null;
      final sanitizedHeaders = headers.map((h) => _sanitizeForFallbackFont(h)).toList();
      final sanitizedRows = rows.map((r) => 
        r.map((c) => _sanitizeForFallbackFont(c?.toString() ?? '')).toList()
      ).toList();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(sanitizedTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              if (sanitizedSubtitle != null)
                pw.Text(sanitizedSubtitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
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
              headers: sanitizedHeaders,
              data: sanitizedRows,
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
      
      print('✅ PDF: File saved to ${file.path}');
      return file;
    } catch (e, stack) {
      print('❌ PDF export error: $e');
      print('Stack: $stack');
      return null;
    }
  }

  /// Preview PDF - opens in Preview app (macOS) or default PDF viewer
  /// User can view the report and save/print using Cmd+S or Cmd+P
  /// Returns true if successful, false otherwise
  Future<bool> previewPdf({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String? subtitle,
  }) async {
    try {
      print('📄 PDF Preview: Starting...');
      
      // Validate data
      if (rows.isEmpty) {
        print('⚠️ PDF Preview: No data to preview');
        return false;
      }
      
      print('📄 PDF Preview: Loading font...');
      final font = await _loadFont();
      print('📄 PDF Preview: Font loaded, creating document...');
      
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: font),
      );
      
      // Sanitize text if using fallback font
      final sanitizedTitle = _sanitizeForFallbackFont(title);
      final sanitizedSubtitle = subtitle != null ? _sanitizeForFallbackFont(subtitle) : null;
      final sanitizedHeaders = headers.map((h) => _sanitizeForFallbackFont(h)).toList();
      final sanitizedRows = rows.map((r) => 
        r.map((c) => _sanitizeForFallbackFont(c?.toString() ?? '')).toList()
      ).toList();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(sanitizedTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              if (sanitizedSubtitle != null)
                pw.Text(sanitizedSubtitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
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
              headers: sanitizedHeaders,
              data: sanitizedRows,
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
      
      print('📄 PDF Preview: Document built, saving to file...');
      final bytes = await pdf.save();
      
      // Save to temp directory and open in Preview app
      final dir = await getTemporaryDirectory();
      final fname = 'RuchiServ_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fname');
      await file.writeAsBytes(bytes);
      
      print('📂 PDF Preview: Opening in Preview app...');
      final opened = await _openInDefaultApp(file.path);
      
      if (!opened) {
        print('⚠️ PDF Preview: Failed to open in Preview, falling back to share...');
        await Printing.sharePdf(bytes: bytes, filename: fname);
      }
      
      print('✅ PDF Preview: Complete!');
      return true;
    } catch (e, stack) {
      print('❌ PDF preview error: $e');
      print('Stack: $stack');
      return false;
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
    // exportToExcel now opens in default app for viewing
    await exportToExcel(
      title: title,
      headers: headers,
      rows: rows,
      openInApp: true,
    );
  }
}
