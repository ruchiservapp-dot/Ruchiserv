// lib/services/invoice_pdf_service.dart
// GST-Compliant Invoice PDF Generation
// Created: 2025-12-17 | Generates professional invoice PDFs with CGST/SGST/IGST
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoicePdfService {
  /// Generate and preview invoice PDF
  static Future<bool> previewInvoice(int invoiceId) async {
    try {
      final pdfBytes = await _generateInvoicePdf(invoiceId);
      if (pdfBytes == null) return false;
      
      await Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(pdfBytes));
      return true;
    } catch (e) {
      print('❌ Invoice PDF preview error: $e');
      return false;
    }
  }

  /// Generate, save and share invoice PDF
  static Future<File?> shareInvoice(int invoiceId) async {
    try {
      final pdfBytes = await _generateInvoicePdf(invoiceId);
      if (pdfBytes == null) return null;
      
      final invoice = await DatabaseHelper().getInvoiceWithItems(invoiceId);
      final invoiceNumber = invoice?['invoiceNumber'] ?? 'invoice';
      
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$invoiceNumber.pdf');
      await file.writeAsBytes(pdfBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Invoice $invoiceNumber',
      );
      
      return file;
    } catch (e) {
      print('❌ Invoice share error: $e');
      return null;
    }
  }

  /// Generate invoice PDF bytes
  static Future<List<int>?> _generateInvoicePdf(int invoiceId) async {
    // Get invoice data
    final invoice = await DatabaseHelper().getInvoiceWithItems(invoiceId);
    if (invoice == null) return null;
    
    // Get firm details
    final prefs = await SharedPreferences.getInstance();
    final firmId = prefs.getString('last_firm') ?? 'DEFAULT';
    final db = DatabaseHelper();
    final firmData = await (await db.database).query('firms', where: 'firmId = ?', whereArgs: [firmId]);
    final firm = firmData.isNotEmpty ? firmData.first : <String, dynamic>{};
    
    final items = (invoice['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    // Create PDF document
    final pdf = pw.Document();
    
    // Date formatter
    final dateFormat = DateFormat('dd MMM yyyy');
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(firm, invoice),
              pw.SizedBox(height: 20),
              
              // Customer & Invoice Info
              _buildCustomerSection(invoice, dateFormat),
              pw.SizedBox(height: 20),
              
              // Items Table
              _buildItemsTable(items),
              pw.SizedBox(height: 20),
              
              // Totals
              _buildTotalsSection(invoice),
              pw.SizedBox(height: 30),
              
              // Footer
              _buildFooter(firm),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }

  static pw.Widget _buildHeader(Map<String, dynamic> firm, Map<String, dynamic> invoice) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Firm Details
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                firm['name']?.toString() ?? 'Your Company',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              if (firm['address'] != null)
                pw.Text(firm['address'].toString(), style: const pw.TextStyle(fontSize: 10)),
              if (firm['mobile'] != null)
                pw.Text('Ph: ${firm['mobile']}', style: const pw.TextStyle(fontSize: 10)),
              if (firm['gstin'] != null)
                pw.Text('GSTIN: ${firm['gstin']}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        // Invoice Title
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'TAX INVOICE',
                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              invoice['invoiceNumber']?.toString() ?? '',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildCustomerSection(Map<String, dynamic> invoice, DateFormat dateFormat) {
    final invoiceDate = invoice['invoiceDate'] != null 
        ? dateFormat.format(DateTime.parse(invoice['invoiceDate'].toString()))
        : '';
    final dueDate = invoice['dueDate'] != null 
        ? dateFormat.format(DateTime.parse(invoice['dueDate'].toString()))
        : '';
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Bill To
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Bill To:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(
                  invoice['customerName']?.toString() ?? 'Customer',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                if (invoice['customerAddress'] != null)
                  pw.Text(invoice['customerAddress'].toString(), style: const pw.TextStyle(fontSize: 10)),
                if (invoice['customerMobile'] != null)
                  pw.Text('Ph: ${invoice['customerMobile']}', style: const pw.TextStyle(fontSize: 10)),
                if (invoice['customerGstin'] != null)
                  pw.Text('GSTIN: ${invoice['customerGstin']}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          // Invoice Details
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildDetailRow('Date:', invoiceDate),
                _buildDetailRow('Due Date:', dueDate),
                _buildDetailRow('Status:', invoice['status']?.toString() ?? 'UNPAID'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<Map<String, dynamic>> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(0.8),
        6: const pw.FlexColumnWidth(1.2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableCell('#', isHeader: true),
            _tableCell('Description', isHeader: true),
            _tableCell('HSN', isHeader: true),
            _tableCell('Qty', isHeader: true),
            _tableCell('Rate', isHeader: true),
            _tableCell('GST%', isHeader: true),
            _tableCell('Amount', isHeader: true),
          ],
        ),
        // Items
        ...items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final item = entry.value;
          return pw.TableRow(
            children: [
              _tableCell('$idx'),
              _tableCell(item['description']?.toString() ?? ''),
              _tableCell(item['hsnCode']?.toString() ?? '-'),
              _tableCell('${item['quantity'] ?? 1}'),
              _tableCell('Rs.${(item['rate'] as num?)?.toStringAsFixed(0) ?? '0'}'),
              _tableCell('${item['gstRate'] ?? 18}%'),
              _tableCell('Rs.${(item['totalAmount'] as num?)?.toStringAsFixed(0) ?? '0'}'),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _buildTotalsSection(Map<String, dynamic> invoice) {
    final subtotal = (invoice['subtotal'] as num?)?.toDouble() ?? 0;
    final cgst = (invoice['cgst'] as num?)?.toDouble() ?? 0;
    final sgst = (invoice['sgst'] as num?)?.toDouble() ?? 0;
    final igst = (invoice['igst'] as num?)?.toDouble() ?? 0;
    final total = (invoice['totalAmount'] as num?)?.toDouble() ?? 0;
    final paid = (invoice['amountPaid'] as num?)?.toDouble() ?? 0;
    final balance = (invoice['balanceDue'] as num?)?.toDouble() ?? total;
    
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 200,
          child: pw.Column(
            children: [
              _totalRow('Subtotal', subtotal),
              if (cgst > 0) _totalRow('CGST', cgst),
              if (sgst > 0) _totalRow('SGST', sgst),
              if (igst > 0) _totalRow('IGST', igst),
              pw.Divider(color: PdfColors.grey400),
              _totalRow('Total', total, isBold: true),
              if (paid > 0) _totalRow('Paid', paid, color: PdfColors.green700),
              if (balance > 0) _totalRow('Balance Due', balance, isBold: true, color: PdfColors.red700),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _totalRow(String label, double amount, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(
            'Rs.${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(Map<String, dynamic> firm) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('1. Payment is due within 7 days of invoice date.', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('2. Please include invoice number with your payment.', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Bank Details:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(firm['bankName']?.toString() ?? 'Bank Name', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('A/C: ${firm['bankAccount'] ?? 'XXXXXXXXXXXX'}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('IFSC: ${firm['ifscCode'] ?? 'XXXXXXXX'}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.SizedBox(height: 30),
                pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
