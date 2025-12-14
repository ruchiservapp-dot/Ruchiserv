// lib/services/report_export_service.dart
// Export service for Reports - Excel, PDF, Share
// UPDATED: 2025-12-14 - Fixed Excel save location and PDF deadlock issues
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

  /// Export data to Excel file and automatically open share sheet
  /// Returns the file if successful, null otherwise
  Future<File?> exportToExcel({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String? filename,
    bool autoShare = true, // Automatically open share sheet for visibility
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
      
      final dir = await getApplicationDocumentsDirectory();
      final fname = filename ?? 'report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fname');
      await file.writeAsBytes(bytes);
      
      print('✅ Excel: File saved to ${file.path}');
      print('📊 Excel: ${rows.length} rows exported');
      
      // Automatically open share sheet so user can save to visible location
      if (autoShare) {
        print('📤 Excel: Opening share sheet...');
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: title,
        );
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

  /// Preview/Share PDF - uses Printing.sharePdf to avoid macOS deadlock
  /// Returns true if successful, false otherwise
  /// 
  /// NOTE: Changed from Printing.layoutPdf to Printing.sharePdf to fix
  /// macOS deadlock issue where knowsPageRange semaphore wait blocks forever.
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
      
      print('📄 PDF Preview: Document built, generating bytes...');
      final bytes = await pdf.save();
      
      // Use Printing.sharePdf instead of layoutPdf to avoid macOS deadlock
      // layoutPdf causes knowsPageRange semaphore deadlock on macOS
      print('📄 PDF Preview: Opening share/print dialog...');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );
      
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
    // exportToExcel now auto-shares by default
    await exportToExcel(
      title: title,
      headers: headers,
      rows: rows,
      autoShare: true,
    );
  }
}
