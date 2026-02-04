// lib/services/pdf_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  /// Generate ORDER PDF as bytes (for WhatsApp/S3 upload)
  static Future<List<int>?> generateOrderPdfBytes(Map<String, dynamic> order, List<Map<String, dynamic>> dishes) async {
    try {
      final pdf = pw.Document();
      
      final rawDateStr = order['date'] ?? order['createdAt'] ?? '';
      String dateStr = rawDateStr;
      
      try {
        if (rawDateStr.isNotEmpty) {
          final dt = DateTime.tryParse(rawDateStr);
          if (dt != null) {
            dateStr = DateFormat('dd MMMM yyyy').format(dt);
          }
        }
      } catch (_) {}

      final customerName = order['customerName'] ?? 'Valued Customer';
      final mobile = order['mobile'] ?? '';
      final firmId = order['firmId'] ?? '';
      final firmName = order['firmName'] ?? 'RuchiServ Partner';
      final firmAddress = order['firmAddress'] ?? '';
      final firmMobile = order['firmMobile'] ?? '';
      final firmEmail = order['firmEmail'] ?? '';
      final firmGstin = order['firmGstin'] ?? '';
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _buildHeader(firmName, firmId, firmAddress, firmMobile, firmEmail, firmGstin),
          footer: (context) => _buildFooter(context),
          build: (pw.Context context) {
            return [
              pw.SizedBox(height: 10),
              _buildOrderDetails(order, dateStr, customerName, mobile),
              pw.SizedBox(height: 25),
              _buildDishTable(dishes),
              pw.SizedBox(height: 25),
              _buildTotals(order),
              pw.SizedBox(height: 30),
              _buildNotes(order),
            ];
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      print('❌ PdfService.generateOrderPdfBytes error: $e');
      return null;
    }
  }

  /// Generate and open a PDF for the given order
  static Future<void> generateAndOpenOrderPdf(Map<String, dynamic> order, List<Map<String, dynamic>> dishes) async {
    final bytes = await generateOrderPdfBytes(order, dishes);
    if (bytes != null) {
      String safeName = order['customerName']?.toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'order';
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => Uint8List.fromList(bytes),
        name: 'Order_${order['id']}_$safeName.pdf',
      );
    }
  }

  static pw.Widget _buildHeader(String firmName, String firmId, String address, String mobile, String email, String gstin) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(firmName.toUpperCase(), 
                    style: pw.TextStyle(
                      fontSize: 24, 
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.deepOrange,
                    ),
                  ),
                  if (address.isNotEmpty)
                    pw.Text(address, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  
                  pw.SizedBox(height: 4),
                  pw.Row(children: [
                    if (mobile.isNotEmpty) pw.Text('Phone: $mobile  ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    if (email.isNotEmpty) pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ]),

                  if (gstin.isNotEmpty)
                    pw.Text('GSTIN: $gstin', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('INVOICE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text('ID: $firmId', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.deepOrange, thickness: 2),
      ],
    );
  }

  static pw.Widget _buildOrderDetails(Map<String, dynamic> order, String date, String name, String mobile) {
    // Format Time: 6:36 PM
    String formatTime(String? t) {
      if (t == null || t.isEmpty) return 'N/A';
      try {
        final parts = t.split(':');
        if (parts.length >= 2) {
          int h = int.parse(parts[0]);
          int m = int.parse(parts[1]);
          final dt = DateTime(2026, 1, 1, h, m);
          return DateFormat('h:mm a').format(dt);
        }
      } catch (_) {}
      return t;
    }

    final displayTime = formatTime(order['eventTime'] ?? order['time']);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILL TO', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.Text(mobile, style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(order['location'] ?? order['venue'] ?? '', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('EVENT DETAILS', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    _infoRow('Date', date),
                    _infoRow('Time', displayTime),
                    _infoRow('Pax', (order['totalPax'] ?? order['pax'] ?? 0).toString()),
                  ],
                ),
              ),
            ],
          ),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5, height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SERVICE STYLE', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                  pw.Text(order['serviceType']?.toString().toUpperCase() ?? 'N/A', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('LOGISTICS', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${order['counterCount'] ?? 1} Counters | ${order['staffCount'] ?? 0} Staff', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('$label: ', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildDishTable(List<Map<String, dynamic>> dishes) {
    final headers = ['ITEM DESCRIPTION', 'CATEGORY', 'PAX', 'RATE', 'AMOUNT'];
    final data = dishes.map((d) {
      final pax = int.tryParse(d['pax']?.toString() ?? '0') ?? 0;
      final rate = double.tryParse((d['rate'] ?? d['pricePerPlate'])?.toString() ?? '0') ?? 0;
      final amount = pax * rate;
      final dishName = d['dishName'] ?? d['name'] ?? '';
      return [
        dishName.toUpperCase(),
        d['category']?.toString().toUpperCase() ?? '',
        pax.toString(),
        'INR ${rate.toStringAsFixed(0)}',
        'INR ${amount.toStringAsFixed(0)}',
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.deepOrange),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.all(8),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(0.8),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildTotals(Map<String, dynamic> order) {
    final grandTotal = double.tryParse(order['grandTotal']?.toString() ?? '0') ?? 0;
    final discountAmount = double.tryParse(order['discountAmount']?.toString() ?? '0') ?? 0;
    final discountPercent = double.tryParse(order['discountPercent']?.toString() ?? '0') ?? 0;
    final subtotal = (order['beforeDiscount'] != null) 
        ? double.tryParse(order['beforeDiscount'].toString()) ?? (grandTotal + discountAmount)
        : (grandTotal + discountAmount);
    
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 250,
        child: pw.Column(
          children: [
            _totalRow('Subtotal', 'INR ${subtotal.toStringAsFixed(0)}', isBold: false),
            if (discountAmount > 0) ...[
              pw.SizedBox(height: 4),
              _totalRow('Discount ($discountPercent%)', '- INR ${discountAmount.toStringAsFixed(0)}', isBold: false, color: PdfColors.red),
            ],
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(
                color: PdfColors.deepOrange,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: _totalRow('GRAND TOTAL', 'INR ${grandTotal.toStringAsFixed(0)}', isBold: true, color: PdfColors.white),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, {bool isBold = false, PdfColor color = PdfColors.black}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      ],
    );
  }

  static pw.Widget _buildNotes(Map<String, dynamic> order) {
    final notes = order['notes'] ?? '';
    if (notes.isEmpty) return pw.SizedBox();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('NOTES/REMARKS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(notes, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated by RuchiServ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
            pw.Text('Thank you for choosing us!', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          ],
        ),
      ],
    );
  }
}
