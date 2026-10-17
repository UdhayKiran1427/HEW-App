import 'package:intl/intl.dart';

enum VoiceActionType {
  expense,
  whereKept,
  renewal,
  unknown,
}

class ParsedVoiceAction {
  VoiceActionType type;
  String originalText;

  // Expense fields
  double? expenseAmount;
  String? expenseCategoryName;
  String? expenseNote;

  // Where Kept fields
  String? itemName;
  String? itemLocation;
  String? inUseBy;

  // Renewal fields
  String? renewalTitle;
  String? renewalCategory;
  String? renewalExpiryDate; // YYYY-MM-DD
  double? renewalAmount;
  String? renewalNotes;

  ParsedVoiceAction({
    required this.type,
    required this.originalText,
    this.expenseAmount,
    this.expenseCategoryName,
    this.expenseNote,
    this.itemName,
    this.itemLocation,
    this.inUseBy,
    this.renewalTitle,
    this.renewalCategory,
    this.renewalExpiryDate,
    this.renewalAmount,
    this.renewalNotes,
  });
}

class HinglishVoiceParser {
  static ParsedVoiceAction parse(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return ParsedVoiceAction(type: VoiceActionType.unknown, originalText: rawText);
    }

    final lower = text.toLowerCase();

    // 1. Detect if RENEWAL / WARRANTY
    final renewalKeywords = [
      'renew', 'renewal', 'expire', 'expiry', 'expiring',
      'khatam', 'validity', 'warranty', 'guarantee',
      'subscription', 'insurance', 'policy'
    ];
    final isRenewal = renewalKeywords.any((kw) => lower.contains(kw));

    // 2. Detect if WHERE KEPT (Item location)
    final whereKeptKeywords = [
      'rakha', 'rakhi', 'rakhe', 'rakh diya', 'kept', 'put',
      'drawer', 'almirah', 'almari', 'cupboard', 'shelf', 'table',
      'bag', 'backpack', 'pocket', 'box', 'dabba', 'sofa', 'fridge',
      'bed', 'wardrobe', 'locker', 'car mein', 'room mein', 'kitchen',
      'hall', 'bathroom', 'shoe rack', 'stand pe'
    ];
    final isWhereKept = whereKeptKeywords.any((kw) => lower.contains(kw));

    // 3. Amount Extraction (₹, Rs, Rupaye, Rupees, numbers)
    final amount = _extractAmount(lower);

    // Decision Logic:
    if (isRenewal) {
      return _parseRenewal(text, lower, amount);
    } else if (isWhereKept && amount == null) {
      return _parseWhereKept(text, lower);
    } else if (amount != null || _hasExpenseKeywords(lower)) {
      return _parseExpense(text, lower, amount);
    } else if (isWhereKept) {
      return _parseWhereKept(text, lower);
    }

    // Default Fallback: If amount exists -> expense, otherwise where kept
    if (amount != null) {
      return _parseExpense(text, lower, amount);
    }

    return _parseWhereKept(text, lower);
  }

  // -------------------------------------------------------------
  // Parse Expense
  // -------------------------------------------------------------
  static ParsedVoiceAction _parseExpense(String text, String lower, double? amount) {
    String categoryName = 'Other';

    // Food
    if (_matchesAny(lower, [
      'chai', 'tea', 'coffee', 'breakfast', 'lunch', 'dinner', 'nasta', 'nashta',
      'samosa', 'khana', 'zomato', 'swiggy', 'grocery', 'kirana', 'doodh', 'milk',
      'sabzi', 'vegetable', 'fruit', 'sweets', 'roti', 'snack', 'restaurant', 'cafe',
      'burger', 'pizza', 'biryani', 'mcdonalds', 'kfc', 'food', 'eating'
    ])) {
      categoryName = 'Food';
    }
    // Travel
    else if (_matchesAny(lower, [
      'petrol', 'diesel', 'fuel', 'auto', 'uber', 'ola', 'cab', 'taxi', 'rickshaw',
      'train', 'metro', 'bus', 'fare', 'toll', 'flight', 'ticket', 'travel', 'parking',
      'ride', 'scooter', 'bike'
    ])) {
      categoryName = 'Travel';
    }
    // Bills
    else if (_matchesAny(lower, [
      'bijli', 'electricity', 'wifi', 'broadband', 'internet', 'water', 'gas',
      'cylinder', 'bill', 'recharge', 'rent', 'kiraya', 'maintenance'
    ])) {
      categoryName = 'Bills';
    }
    // Shopping
    else if (_matchesAny(lower, [
      'clothes', 'kapde', 'shoes', 'joote', 'amazon', 'flipkart', 'myntra',
      'shopping', 'dress', 'shirt', 'jeans', 'tshirt', 'watch', 'bag', 'mall'
    ])) {
      categoryName = 'Shopping';
    }
    // Health
    else if (_matchesAny(lower, [
      'medicine', 'dawa', 'dawaii', 'doctor', 'hospital', 'clinic', 'pharmacy',
      'chemist', 'tablet', 'syrup', 'medical', 'test', 'blood test'
    ])) {
      categoryName = 'Health';
    }

    // Clean up note text (remove filler words)
    String cleanNote = text;
    final fillers = [
      'rupaye', 'rupee', 'rupees', 'rs', 'inr', 'kharch', 'kharcha', 'kiya', 'kiye',
      'spent', 'spend', 'paid', 'pay', 'diya', 'diye', 'ka', 'ke', 'pe', 'mein', 'for'
    ];
    // Remove amount digits
    if (amount != null) {
      final amtInt = amount.toInt();
      cleanNote = cleanNote.replaceAll(RegExp('\\b$amtInt(\\.\\d+)?\\b'), '');
    }
    for (final f in fillers) {
      cleanNote = cleanNote.replaceAll(RegExp('\\b$f\\b', caseSensitive: false), ' ');
    }
    cleanNote = cleanNote.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanNote.isEmpty) {
      cleanNote = '$categoryName expense';
    } else {
      // Capitalize first letter
      cleanNote = cleanNote[0].toUpperCase() + cleanNote.substring(1);
    }

    return ParsedVoiceAction(
      type: VoiceActionType.expense,
      originalText: text,
      expenseAmount: amount ?? 0.0,
      expenseCategoryName: categoryName,
      expenseNote: cleanNote,
    );
  }

  // -------------------------------------------------------------
  // Parse Where Kept
  // -------------------------------------------------------------
  static ParsedVoiceAction _parseWhereKept(String text, String lower) {
    String item = '';
    String location = 'Room';
    String? lentTo;

    // Check for "lent to" / "ko diya hai"
    final lentMatch = RegExp(r'([A-Za-z]+)\s+ko\s+diya', caseSensitive: false).firstMatch(text) ??
        RegExp(r'given\s+to\s+([A-Za-z]+)', caseSensitive: false).firstMatch(text) ??
        RegExp(r'lent\s+to\s+([A-Za-z]+)', caseSensitive: false).firstMatch(text);

    if (lentMatch != null) {
      lentTo = lentMatch.group(1);
    }

    // Pattern 1: "[Item] [Location] mein rakha hai" or "pe hai"
    // e.g., "Passport bedroom drawer mein rakha hai"
    final regexIn = RegExp(r'^(.*?)\s+(.*?)\s+(mein|pe|par|in|on|at|inside)\s*(rakha|rakhi|hai|kept|put)?', caseSensitive: false);
    final match = regexIn.firstMatch(text);

    if (match != null && match.group(1)!.trim().isNotEmpty && match.group(2)!.trim().isNotEmpty) {
      item = match.group(1)!.trim();
      location = '${match.group(2)!.trim()} (${match.group(3)!.toLowerCase()})';
    } else {
      // Fallback splitting
      final parts = text.split(RegExp(r'\b(mein|pe|par|in|on|at|inside)\b', caseSensitive: false));
      if (parts.length >= 2) {
        item = parts[0].trim();
        location = parts[1].replaceAll(RegExp(r'\b(rakha|rakhi|hai|kept|put)\b', caseSensitive: false), '').trim();
      } else {
        item = text.replaceAll(RegExp(r'\b(rakha|rakhi|hai|kept|put)\b', caseSensitive: false), '').trim();
        location = 'General Storage';
      }
    }

    // Clean up item name
    item = item.replaceAll(RegExp(r'\b(mera|meri|my|the|a)\b', caseSensitive: false), '').trim();
    if (item.isNotEmpty) {
      item = item[0].toUpperCase() + item.substring(1);
    } else {
      item = 'Belonging';
    }

    if (location.trim().isEmpty) {
      location = 'Storage Box / Drawer';
    }

    return ParsedVoiceAction(
      type: VoiceActionType.whereKept,
      originalText: text,
      itemName: item,
      itemLocation: location,
      inUseBy: lentTo,
    );
  }

  // -------------------------------------------------------------
  // Parse Renewal / Warranty
  // -------------------------------------------------------------
  static ParsedVoiceAction _parseRenewal(String text, String lower, double? amount) {
    String category = 'Subscription';
    if (lower.contains('recharge') || lower.contains('phone') || lower.contains('jio') || lower.contains('airtel')) {
      category = 'Recharge';
    } else if (lower.contains('warranty') || lower.contains('guarantee')) {
      category = 'Warranty';
    } else if (lower.contains('insurance') || lower.contains('policy') || lower.contains('bima')) {
      category = 'Insurance';
    } else if (lower.contains('service') || lower.contains('maintenance')) {
      category = 'Service';
    }

    // Expiry Date calculation
    DateTime targetDate = DateTime.now().add(const Duration(days: 30)); // default 30 days
    final daysMatch = RegExp(r'(\d+)\s*(din|days?)\s*(baad|after)?', caseSensitive: false).firstMatch(lower);
    if (daysMatch != null) {
      final days = int.tryParse(daysMatch.group(1)!) ?? 30;
      targetDate = DateTime.now().add(Duration(days: days));
    } else if (lower.contains('kal') || lower.contains('tomorrow')) {
      targetDate = DateTime.now().add(const Duration(days: 1));
    } else if (lower.contains('parso')) {
      targetDate = DateTime.now().add(const Duration(days: 2));
    } else if (lower.contains('next month') || lower.contains('agle mahine')) {
      targetDate = DateTime.now().add(const Duration(days: 30));
    }

    // Title extraction
    String title = text;
    final wordsToRemove = [
      'renew', 'renewal', 'karna', 'hai', 'expire', 'expiry', 'khatam', 'ho', 'raha', 'hogi',
      'din', 'baad', 'days', 'after', 'rupaye', 'rs', 'rupees', 'ka', 'ki', 'ke', 'ko'
    ];
    if (amount != null) {
      final amtInt = amount.toInt();
      title = title.replaceAll(RegExp('\\b$amtInt\\b'), '');
    }
    for (final w in wordsToRemove) {
      title = title.replaceAll(RegExp('\\b$w\\b', caseSensitive: false), ' ');
    }
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) {
      title = '$category Tracker';
    } else {
      title = title[0].toUpperCase() + title.substring(1);
    }

    final dateFormat = DateFormat('yyyy-MM-dd');

    return ParsedVoiceAction(
      type: VoiceActionType.renewal,
      originalText: text,
      renewalTitle: title,
      renewalCategory: category,
      renewalExpiryDate: dateFormat.format(targetDate),
      renewalAmount: amount,
      renewalNotes: 'Added via voice: "$text"',
    );
  }

  // Helper: Amount Extractor
  static double? _extractAmount(String lower) {
    // Pattern 1: ₹ 250 or Rs. 250 or 250 rs or 250 rupaye
    final p1 = RegExp(r'(?:₹|rs\.?|inr|rupaye|rupees?)\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(lower);
    if (p1 != null) return double.tryParse(p1.group(1)!);

    final p2 = RegExp(r'(\d+(?:\.\d+)?)\s*(?:₹|rs\.?|inr|rupaye|rupees?|bucks|\/-)', caseSensitive: false).firstMatch(lower);
    if (p2 != null) return double.tryParse(p2.group(1)!);

    // Pattern 3: "299 ka" or "for 500" or "spent 150"
    final p3 = RegExp(r'(?:spent|kharch|paid|diye|for|cost)\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(lower);
    if (p3 != null) return double.tryParse(p3.group(1)!);

    final p4 = RegExp(r'(\d+(?:\.\d+)?)\s*ka\b', caseSensitive: false).firstMatch(lower);
    if (p4 != null) return double.tryParse(p4.group(1)!);

    // Pattern 5: Any standalone digits (e.g. "Chai 20")
    final p5 = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(lower);
    if (p5 != null) {
      final val = double.tryParse(p5.group(1)!);
      if (val != null && val > 0 && val < 1000000) {
        return val;
      }
    }

    return null;
  }

  static bool _hasExpenseKeywords(String lower) {
    return _matchesAny(lower, [
      'spent', 'kharch', 'kharcha', 'paid', 'pay', 'diya', 'diye', 'buy', 'bought',
      'kharida', 'khareeda', 'bill'
    ]);
  }

  static bool _matchesAny(String text, List<String> words) {
    return words.any((w) => RegExp('\\b$w\\b', caseSensitive: false).hasMatch(text) || text.contains(w));
  }
}

