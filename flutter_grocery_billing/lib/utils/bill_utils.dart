class BillUtils {
  static String generateBillNumber() {
    final now = DateTime.now();
    final yy = now.year.toString().substring(2);
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final rand = (1000 + (now.millisecondsSinceEpoch % 9000)).toString();
    return 'B$yy$mm$dd-$rand';
  }

  static String formatCurrency(double amount, {String currency = '৳'}) {
    return '$currency${amount.toStringAsFixed(2)}';
  }

  static String toBengaliDigits(dynamic number) {
    const en = '0123456789';
    const bn = '০১২৩৪৫৬৭৮৯';
    return number.toString().split('').map((c) {
      final idx = en.indexOf(c);
      return idx >= 0 ? bn[idx] : c;
    }).join();
  }
}
