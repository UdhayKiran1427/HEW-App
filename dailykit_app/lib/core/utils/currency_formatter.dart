import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(num amount, {String currency = 'INR'}) {
    final symbol = getSymbol(currency);
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    );
    return formatter.format(amount);
  }

  static String getSymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '$currency ';
    }
  }
}

