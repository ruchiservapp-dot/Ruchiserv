import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<Map<String, dynamic>> extractInvoiceData(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);

    String rawText = recognizedText.text;
    double? amount = _extractAmount(rawText);
    String? date = _extractDate(rawText);

    return {
      'amount': amount,
      'date': date,
      'rawText': rawText,
    };
  }

  double? _extractAmount(String text) {
    // Look for patterns like Total, Amount, Grand Total followed by a number
    // Regex for currency patterns: (Total|Amount|Grand Total|Net Amount)[:\s]*[₹$]?\s*([\d,]+\.?\d*)
    final RegExp amountRegExp = RegExp(
      r'(?:Total|Amount|Grand Total|Net Amount|Total Payable|Payable Amount)[:\s]*[₹$£]?\s*([\d,]+\.?\d{0,2})',
      caseSensitive: false,
    );

    final matches = amountRegExp.allMatches(text);
    if (matches.isNotEmpty) {
      // Find the largest value found or the one that seems most like a total
      double maxAmount = 0;
      for (var match in matches) {
        String amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
        double val = double.tryParse(amountStr) ?? 0;
        if (val > maxAmount) maxAmount = val;
      }
      return maxAmount > 0 ? maxAmount : null;
    }

    // Fallback: search for any number that looks like a total (at the bottom or after keywords)
    return null;
  }

  String? _extractDate(String text) {
    // Patterns: DD/MM/YYYY, DD-MM-YYYY, YYYY/MM/DD, etc.
    final RegExp dateRegExp = RegExp(
      r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})|(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
      caseSensitive: false,
    );

    final match = dateRegExp.firstMatch(text);
    return match?.group(0);
  }

  void dispose() {
    _textRecognizer.close();
  }
}
