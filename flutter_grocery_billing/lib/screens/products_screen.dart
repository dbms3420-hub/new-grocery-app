import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/database_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  final _units = ['kg', 'g', 'liter', 'ml', 'piece', 'dozen', 'pack', 'box'];
  final _categories = ['Vegetables', 'Fruits', 'Dairy', 'Grains', 'Spices', 'Oils', 'Beverages', 'Other'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await DatabaseService.instance.getAllProducts();
    setState(() {
      _products = all;
      _loading = false;
    });
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) { _load(); return; }
    final results = await DatabaseService.instance.searchProducts(q);
    setState(() => _products = results);
  }

  void _showForm({Product? product}) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final nameBnCtrl = TextEditingController(text: product?.nameBn ?? '');
    final priceCtrl = TextEditingController(text: product?.price.toString() ?? '');
    final barcodeCtrl = TextEditingController(text: product?.barcode ?? '');
    String unit = product?.unit ?? 'kg';
    String category = product?.category ?? 'Other';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(product == null ? 'নতুন পণ্য যোগ করুন' : 'পণ্য সম্পাদনা',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                _field(nameBnCtrl, 'পণ্যের নাম (বাংলা) *', Icons.inventory_2_outlined),
                const SizedBox(height: 10),
                _field(nameCtrl, 'Product Name (English) *', Icons.inventory_outlined),
                const SizedBox(height: 10),
                _field(priceCtrl, 'দাম (৳) *', Icons.currency_exchange,
                    type: TextInputType.number),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('একক', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: unit,
                            onChanged: (v) => setLocal(() => unit = v!),
                            items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('বিভাগ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: category,
                            onChanged: (v) => setLocal(() => category = v!),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                _field(barcodeCtrl, 'Barcode (optional)', Icons.qr_code),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty && nameBnCtrl.text.trim().isEmpty) return;
                    final price = double.tryParse(priceCtrl.text);
                    if (price == null || price <= 0) return;

                    final p = Product(
                      id: product?.id,
                      name: nameCtrl.text.trim().isNotEmpty
                          ? nameCtrl.text.trim()
                          : nameBnCtrl.text.trim(),
                      nameBn: nameBnCtrl.text.trim().isEmpty ? null : nameBnCtrl.text.trim(),
                      price: price,
                      unit: unit,
                      category: category,
                      barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                    );

                    if (product == null) {
                      await DatabaseService.instance.insertProduct(p);
                    } else {
                      await DatabaseService.instance.updateProduct(p);
                    }

                    if (context.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('সেভ করুন',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('পণ্য তালিকা'),
            Text('${_products.length}টি পণ্য',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('নতুন পণ্য'),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF2E7D32),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'পণ্য খুঁজুন...',
                hintStyle: TextStyle(color: Colors.green[200]),
                prefixIcon: Icon(Icons.search, color: Colors.green[200]),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _products.length,
                    itemBuilder: (_, i) {
                      final p = _products[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.inventory_2, color: Color(0xFF2E7D32), size: 22),
                          ),
                          title: Text(p.nameBn ?? p.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Row(children: [
                            Text('৳${p.price}/${p.unit}',
                                style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                            if (p.category != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(p.category!, style: const TextStyle(fontSize: 10)),
                              ),
                            ],
                          ]),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                onPressed: () => _showForm(product: p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () async {
                                  await DatabaseService.instance.deleteProduct(p.id!);
                                  _load();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
