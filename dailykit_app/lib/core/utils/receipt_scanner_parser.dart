import 'package:intl/intl.dart';

class ScannedReceiptData {
  final String merchantName;
  final double amount;
  final String categoryName;
  final String date; // YYYY-MM-DD
  final String rawText;
  final List<String> extractedItems;

  ScannedReceiptData({
    required this.merchantName,
    required this.amount,
    required this.categoryName,
    required this.date,
    required this.rawText,
    this.extractedItems = const [],
  });
}

class ReceiptScannerParser {
  static ScannedReceiptData parse(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String merchant = _extractMerchant(lines);
    double amount = _extractTotalAmount(lines, ocrText);
    String date = _extractDate(lines);
    String category = _inferCategory(ocrText, merchant);

    return ScannedReceiptData(
      merchantName: merchant,
      amount: amount,
      categoryName: category,
      date: date,
      rawText: ocrText,
    );
  }

  // 1. Extract Merchant / Store Name
  static String _extractMerchant(List<String> lines) {
    final ignoreKeywords = [
      'tax invoice', 'invoice', 'cash memo', 'receipt', 'bill', 'retail invoice',
      'welcome', 'original', 'duplicate', 'customer copy', 'gst', 'gstin',
      'tel:', 'phone:', 'mob:', 'date:', 'time:', 'order no', 'table no'
    ];

    for (int i = 0; i < lines.length && i < 6; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      // Check if line is header junk
      bool isIgnored = ignoreKeywords.any((kw) => lower.contains(kw));
      // Ignore if mostly numbers or symbols
      bool isNumeric = RegExp(r'^[\d\s\-\:\/\.\,]+$').hasMatch(line);

      if (!isIgnored && !isNumeric && line.length >= 3 && line.length <= 40) {
        // Clean up punctuation
        return line.replaceAll(RegExp(r'[^\w\s\&\.\-]'), '').trim();
      }
    }
    return 'Store / Vendor';
  }

  // 2. Extract Total Amount
  static double _extractTotalAmount(List<String> lines, String fullText) {
    final totalKeywords = [
      'grand total', 'net amount', 'total amount', 'total payable',
      'amount payable', 'total:', 'total', 'bill amount', 'net total',
      'balance due', 'paid amount', 'paid', 'subtotal'
    ];

    double? foundAmount;

    // First scan lines with explicit TOTAL keywords
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final lower = line.toLowerCase();

      for (final kw in totalKeywords) {
        if (lower.contains(kw)) {
          final amt = _extractNumberFromLine(line);
          if (amt != null && amt > 0) {
            return amt;
          }
          // Check subsequent line if amount was on next line
          if (i + 1 < lines.length) {
            final nextAmt = _extractNumberFromLine(lines[i + 1]);
            if (nextAmt != null && nextAmt > 0) {
              return nextAmt;
            }
          }
        }
      }
    }

    // Secondary scan: find highest reasonable currency number with ₹ or Rs or numbers
    final numberRegex = RegExp(r'(?:₹|rs\.?|inr)?\s*(\d{1,6}(?:[.,]\d{2})?)', caseSensitive: false);
    final matches = numberRegex.allMatches(fullText);

    double maxVal = 0.0;
    for (final m in matches) {
      final str = m.group(1)?.replaceAll(',', '');
      final val = double.tryParse(str ?? '');
      // Receipts typically between 5 and 500,000
      if (val != null && val >= 5 && val <= 500000) {
        // Discard typical year numbers like 2024, 2025, 2026
        if (val == 2024 || val == 2025 || val == 2026) continue;
        if (val > maxVal) {
          maxVal = val;
        }
      }
    }

    return foundAmount ?? (maxVal > 0 ? maxVal : 0.0);
  }

  static double? _extractNumberFromLine(String line) {
    final regex = RegExp(r'(\d{1,6}(?:[.,]\d{2})?)');
    final matches = regex.allMatches(line).toList();
    if (matches.isNotEmpty) {
      // Return last number in the line (often amount is on the right)
      final str = matches.last.group(1)?.replaceAll(',', '');
      final parsed = double.tryParse(str ?? '');
      if (parsed != null && parsed != 2024 && parsed != 2025 && parsed != 2026) {
        return parsed;
      }
    }
    return null;
  }

  // 3. Extract Date
  static String _extractDate(List<String> lines) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Matches: DD/MM/YYYY or DD-MM-YYYY or YYYY-MM-DD
    final dateRegex = RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})');

    for (final line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        final d = int.tryParse(match.group(1)!);
        final m = int.tryParse(match.group(2)!);
        var y = int.tryParse(match.group(3)!);

        if (d != null && m != null && y != null) {
          if (y < 100) y += 2000;
          if (m >= 1 && m <= 12 && d >= 1 && d <= 31 && y >= 2020 && y <= 2030) {
            return '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
          }
        }
      }
    }
    return today;
  }

  // 4. Infer Category
  static String _inferCategory(String fullText, String merchant) {
    final text = '$fullText $merchant'.toLowerCase();

    // Food
    if (_matchesAny(text, [
      'restaurant', 'cafe', 'coffee', 'bakery', 'pizza', 'burger', 'sweets',
      'dhaba', 'hotel', 'biryani', 'food', 'dining', 'kitchen', 'snack',
      'zomato', 'swiggy', 'ice cream', 'juice', 'fruit', 'vegetable', 'sabzi',
      'barbeque', 'mcdonald', 'kfc', 'starbucks', 'domino', 'subway', 'tea'
    ])) {
      return 'Food';
    }

    // Travel
    if (_matchesAny(text, [
      'petrol', 'fuel', 'diesel', 'indian oil', 'bharat petroleum', 'hp', 'shell',
      'toll', 'uber', 'ola', 'auto', 'parking', 'fastag', 'metro', 'train',
      'flight', 'airways', 'cng', 'gas station'
    ])) {
      return 'Travel';
    }

    // Health
    if (_matchesAny(text, [
      'pharmacy', 'medical', 'chemist', 'hospital', 'clinic', 'lab', 'healthcare',
      'pharma', 'medicine', 'doctor', 'dental', 'diagnostic', 'apollo', 'medplus',
      'pathology', 'tablet', 'syrup'
    ])) {
      return 'Health';
    }

    // Shopping
    if (_matchesAny(text, [
      'd-mart', 'dmart', 'reliance', 'trend', 'zudio', 'pantaloons', 'apparel',
      'clothes', 'garments', 'supermarket', 'mart', 'mall', 'footwear',
      'shoes', 'amazon', 'flipkart', 'myntra', 'lifestyle', 'westside', 'h&m', 'zara'
    ])) {
      return 'Shopping';
    }

    // Bills
    if (_matchesAny(text, [
      'electricity', 'bescom', 'tneb', 'bses', 'power', 'discom', 'water',
      'cylinder', 'broadband', 'airtel', 'jio', 'vodafone', 'vi', 'recharge',
      'maintenance', 'bill', 'utility'
    ])) {
      return 'Bills';
    }

    return 'Other';
  }

  static bool _matchesAny(String text, List<String> words) {
    return words.any((w) => text.contains(w));
  }
}

