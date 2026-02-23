import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../utils/file_storage_helper.dart';

class InvoiceScannerWidget extends StatefulWidget {
  final Function(Map<String, dynamic> result) onScanComplete;
  
  const InvoiceScannerWidget({super.key, required this.onScanComplete});

  @override
  State<InvoiceScannerWidget> createState() => _InvoiceScannerWidgetState();
}

class _InvoiceScannerWidgetState extends State<InvoiceScannerWidget> {
  final _ocrService = OCRService();
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    
    if (image == null) return;

    setState(() => _isProcessing = true);

    try {
      final File imageFile = File(image.path);
      
      // 1. Run OCR
      final ocrResult = await _ocrService.extractInvoiceData(imageFile);
      
      if (!mounted) return;

      // 2. Show confirmation dialog with the original image (before upload)
      final finalData = await _showConfirmationDialog(
        amount: ocrResult['amount'],
        date: ocrResult['date'],
        imagePath: image.path, // Show original pick for preview
      );

      if (finalData != null) {
        // 3. Upload to S3 (with compression) after user confirms
        setState(() => _isProcessing = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading invoice to cloud...'), duration: Duration(seconds: 2)),
          );
        }

        final savedKey = await FileStorageHelper.saveAndUploadImage(imageFile, fileType: 'invoices');

        widget.onScanComplete({
          ...finalData,
          'imageUrl': savedKey,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing invoice: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<Map<String, dynamic>?> _showConfirmationDialog({
    double? amount,
    String? date,
    required String imagePath,
  }) async {
    final amountController = TextEditingController(text: amount?.toStringAsFixed(2) ?? '');
    final dateController = TextEditingController(text: date ?? '');

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Invoice Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 200,
                child: Image.file(File(imagePath), fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Invoice Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.datetime,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'amount': double.tryParse(amountController.text) ?? 0.0,
                'date': dateController.text,
              });
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Analyzing invoice...'),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Invoice'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('From Gallery'),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'OCR will try to auto-extract amount and date',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
