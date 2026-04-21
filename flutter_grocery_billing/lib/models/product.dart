class Product {
  final int? id;
  final String name;
  final String? nameBn;
  final double price;
  final String unit;
  final String? category;
  final String? barcode;
  final DateTime createdAt;

  Product({
    this.id,
    required this.name,
    this.nameBn,
    required this.price,
    required this.unit,
    this.category,
    this.barcode,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'name_bn': nameBn,
        'price': price,
        'unit': unit,
        'category': category,
        'barcode': barcode,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        nameBn: map['name_bn'] as String?,
        price: (map['price'] as num).toDouble(),
        unit: map['unit'] as String,
        category: map['category'] as String?,
        barcode: map['barcode'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  Product copyWith({
    int? id,
    String? name,
    String? nameBn,
    double? price,
    String? unit,
    String? category,
    String? barcode,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        nameBn: nameBn ?? this.nameBn,
        price: price ?? this.price,
        unit: unit ?? this.unit,
        category: category ?? this.category,
        barcode: barcode ?? this.barcode,
        createdAt: createdAt,
      );
}
