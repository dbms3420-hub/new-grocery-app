import 'bill_item.dart';

enum PaymentMode { cash, upi, card, credit }

extension PaymentModeExt on PaymentMode {
  String get label {
    switch (this) {
      case PaymentMode.cash:
        return 'নগদ / Cash';
      case PaymentMode.upi:
        return 'UPI / Mobile';
      case PaymentMode.card:
        return 'Card / কার্ড';
      case PaymentMode.credit:
        return 'বাকি / Credit';
    }
  }

  String get value => name;

  static PaymentMode fromString(String s) =>
      PaymentMode.values.firstWhere((e) => e.name == s, orElse: () => PaymentMode.cash);
}

class Bill {
  final int? id;
  final String billNumber;
  final List<BillItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? customerName;
  final String? customerPhone;
  final PaymentMode paymentMode;
  final String? notes;
  final DateTime createdAt;

  Bill({
    this.id,
    required this.billNumber,
    required this.items,
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    this.customerName,
    this.customerPhone,
    this.paymentMode = PaymentMode.cash,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'bill_number': billNumber,
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'total': total,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'payment_mode': paymentMode.value,
        'notes': notes,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Bill.fromMap(Map<String, dynamic> map, List<BillItem> items) => Bill(
        id: map['id'] as int?,
        billNumber: map['bill_number'] as String,
        items: items,
        subtotal: (map['subtotal'] as num).toDouble(),
        discount: (map['discount'] as num).toDouble(),
        tax: (map['tax'] as num).toDouble(),
        total: (map['total'] as num).toDouble(),
        customerName: map['customer_name'] as String?,
        customerPhone: map['customer_phone'] as String?,
        paymentMode: PaymentModeExt.fromString(map['payment_mode'] as String),
        notes: map['notes'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}
