class BillItem {
  final int? id;
  final int? billId;
  final int? productId;
  final String name;
  final String? nameBn;
  final double price;
  final double quantity;
  final String unit;
  final double total;

  BillItem({
    this.id,
    this.billId,
    this.productId,
    required this.name,
    this.nameBn,
    required this.price,
    required this.quantity,
    required this.unit,
  }) : total = price * quantity;

  BillItem.withTotal({
    this.id,
    this.billId,
    this.productId,
    required this.name,
    this.nameBn,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'bill_id': billId,
        'product_id': productId,
        'name': name,
        'name_bn': nameBn,
        'price': price,
        'quantity': quantity,
        'unit': unit,
        'total': total,
      };

  factory BillItem.fromMap(Map<String, dynamic> map) => BillItem.withTotal(
        id: map['id'] as int?,
        billId: map['bill_id'] as int?,
        productId: map['product_id'] as int?,
        name: map['name'] as String,
        nameBn: map['name_bn'] as String?,
        price: (map['price'] as num).toDouble(),
        quantity: (map['quantity'] as num).toDouble(),
        unit: map['unit'] as String,
        total: (map['total'] as num).toDouble(),
      );

  BillItem copyWith({int? billId}) => BillItem.withTotal(
        id: id,
        billId: billId ?? this.billId,
        productId: productId,
        name: name,
        nameBn: nameBn,
        price: price,
        quantity: quantity,
        unit: unit,
        total: total,
      );
}
