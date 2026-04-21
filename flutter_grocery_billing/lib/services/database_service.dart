import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';

class DatabaseService {
  static Database? _db;
  static const String _dbName = 'grocery_billing.db';
  static const int _dbVersion = 2;

  // Singleton
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_bn TEXT,
        price REAL NOT NULL,
        unit TEXT NOT NULL DEFAULT 'piece',
        category TEXT,
        barcode TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_number TEXT NOT NULL UNIQUE,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        customer_name TEXT,
        customer_phone TEXT,
        payment_mode TEXT NOT NULL DEFAULT 'cash',
        notes TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id INTEGER NOT NULL,
        product_id INTEGER,
        name TEXT NOT NULL,
        name_bn TEXT,
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (bill_id) REFERENCES bills(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
      )
    ''');

    // Seed sample products
    await _seedProducts(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
    }
  }

  Future<void> _seedProducts(Database db) async {
    final samples = [
      {'name': 'Rice', 'name_bn': 'চাল', 'price': 65.0, 'unit': 'kg', 'category': 'Grains'},
      {'name': 'Wheat Flour', 'name_bn': 'ময়দা', 'price': 45.0, 'unit': 'kg', 'category': 'Grains'},
      {'name': 'Mustard Oil', 'name_bn': 'সরিষার তেল', 'price': 180.0, 'unit': 'liter', 'category': 'Oils'},
      {'name': 'Sugar', 'name_bn': 'চিনি', 'price': 80.0, 'unit': 'kg', 'category': 'Grains'},
      {'name': 'Salt', 'name_bn': 'লবণ', 'price': 25.0, 'unit': 'kg', 'category': 'Spices'},
      {'name': 'Lentils', 'name_bn': 'ডাল', 'price': 110.0, 'unit': 'kg', 'category': 'Grains'},
      {'name': 'Potato', 'name_bn': 'আলু', 'price': 30.0, 'unit': 'kg', 'category': 'Vegetables'},
      {'name': 'Onion', 'name_bn': 'পেঁয়াজ', 'price': 50.0, 'unit': 'kg', 'category': 'Vegetables'},
      {'name': 'Turmeric', 'name_bn': 'হলুদ', 'price': 280.0, 'unit': 'kg', 'category': 'Spices'},
      {'name': 'Milk', 'name_bn': 'দুধ', 'price': 60.0, 'unit': 'liter', 'category': 'Dairy'},
    ];

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final p in samples) {
      await db.insert('products', {...p, 'created_at': now});
    }
  }

  // ─── PRODUCTS ────────────────────────────────────────────────
  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'name_bn ASC, name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final q = '%$query%';
    final maps = await db.query(
      'products',
      where: 'name LIKE ? OR name_bn LIKE ? OR barcode = ?',
      whereArgs: [q, q, query],
    );
    return maps.map(Product.fromMap).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return db.insert('products', product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getProductCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM products');
    return result.first['c'] as int;
  }

  // ─── BILLS ───────────────────────────────────────────────────
  Future<int> insertBill(Bill bill) async {
    final db = await database;

    return db.transaction((txn) async {
      final billId = await txn.insert('bills', bill.toMap());
      for (final item in bill.items) {
        await txn.insert('bill_items', item.copyWith(billId: billId).toMap());
      }
      return billId;
    });
  }

  Future<List<Bill>> getAllBills() async {
    final db = await database;
    final billMaps = await db.query('bills', orderBy: 'created_at DESC');

    final bills = <Bill>[];
    for (final bm in billMaps) {
      final itemMaps = await db.query(
        'bill_items',
        where: 'bill_id = ?',
        whereArgs: [bm['id']],
      );
      bills.add(Bill.fromMap(bm, itemMaps.map(BillItem.fromMap).toList()));
    }
    return bills;
  }

  Future<List<Bill>> getRecentBills({int limit = 20}) async {
    final db = await database;
    final billMaps = await db.query(
      'bills',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    final bills = <Bill>[];
    for (final bm in billMaps) {
      final itemMaps = await db.query(
        'bill_items',
        where: 'bill_id = ?',
        whereArgs: [bm['id']],
      );
      bills.add(Bill.fromMap(bm, itemMaps.map(BillItem.fromMap).toList()));
    }
    return bills;
  }

  Future<void> deleteBill(int id) async {
    final db = await database;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTodaySalesTotal() async {
    final db = await database;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) as total FROM bills WHERE created_at >= ?',
      [start],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<int> getTodayBillCount() async {
    final db = await database;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM bills WHERE created_at >= ?',
      [start],
    );
    return result.first['c'] as int;
  }

  Future<int> getTotalBillCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM bills');
    return result.first['c'] as int;
  }
}
