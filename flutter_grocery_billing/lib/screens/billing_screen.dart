import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/app_settings.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';
import '../services/pdf_service.dart';
import '../utils/bill_utils.dart';

class BillingScreen extends StatefulWidget {
  final AppSettings settings;
  const BillingScreen({super.key, required this.settings});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final VoiceService _voice = VoiceService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<BillItem> _cartItems = [];

  bool _voiceReady = false;
  bool _isListening = false;
  String _voiceTranscript = '';
  String _voiceMessage = '';
  VoiceLang _voiceLang = VoiceLang.bengali;

  double _discount = 0;
  String _paymentMode = 'cash';

  bool _billSuccess = false;
  Bill? _savedBill;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    _voiceLang = widget.settings.defaultLanguage == 'en'
        ? VoiceLang.english
        : VoiceLang.bengali;
    _init();
  }

  Future<void> _init() async {
    final products = await DatabaseService.instance.getAllProducts();
    final voiceReady = await _voice.initialize();
    setState(() {
      _allProducts = products;
      _filteredProducts = products;
      _voiceReady = voiceReady;
    });
  }

  @override
  void dispose() {
    _voice.cancelListening();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    setState(() {
      _filteredProducts = q.isEmpty
          ? _allProducts
          : _allProducts.where((p) =>
              p.name.toLowerCase().contains(q.toLowerCase()) ||
              (p.nameBn?.contains(q) ?? false)).toList();
    });
  }

  void _addToCart(Product p, {double qty = 1}) {
    setState(() {
      final idx = _cartItems.indexWhere((i) => i.productId == p.id);
      if (idx >= 0) {
        final old = _cartItems[idx];
        final newQty = old.quantity + qty;
        _cartItems[idx] = BillItem(
          id: old.id,
          billId: old.billId,
          productId: old.productId,
          name: old.name,
          nameBn: old.nameBn,
          price: old.price,
          quantity: newQty,
          unit: old.unit,
        );
      } else {
        _cartItems.add(BillItem(
          productId: p.id,
          name: p.name,
          nameBn: p.nameBn,
          price: p.price,
          quantity: qty,
          unit: p.unit,
        ));
      }
    });
  }

  void _addAdHocItem(BillItem item) {
    setState(() => _cartItems.add(item));
  }

  void _updateQty(int idx, double delta) {
    setState(() {
      final old = _cartItems[idx];
      final newQty = (old.quantity + delta).clamp(0.5, 9999.0);
      _cartItems[idx] = BillItem(
        id: old.id,
        billId: old.billId,
        productId: old.productId,
        name: old.name,
        nameBn: old.nameBn,
        price: old.price,
        quantity: newQty,
        unit: old.unit,
      );
    });
  }

  void _removeItem(int idx) => setState(() => _cartItems.removeAt(idx));

  // ─── Voice ────────────────────────────────────────────────────
  void _toggleVoice() {
    if (_isListening) {
      _voice.stopListening();
      setState(() => _isListening = false);
    } else {
      _startVoice();
    }
  }

  void _startVoice() {
    if (!_voiceReady) {
      _showMsg('⚠️ মাইক্রোফোন অনুমতি দিন');
      return;
    }
    _voice.startListening(
      lang: _voiceLang,
      onResult: (transcript, isFinal) {
        setState(() {
          _voiceTranscript = transcript;
          _isListening = !isFinal;
        });
        if (isFinal && transcript.isNotEmpty) {
          _processVoice(transcript);
        }
      },
      onError: (err) {
        setState(() => _isListening = false);
        if (err != 'no-speech') _showMsg('⚠️ $err');
      },
    );
    setState(() {
      _isListening = true;
      _voiceTranscript = '';
    });
  }

  void _processVoice(String transcript) {
    final parsed = VoiceService.parseTranscript(transcript);
    final lang = parsed.detectedLang;

    setState(() => _voiceLang = lang);

    if (parsed.isCancelCommand) {
      setState(() => _cartItems.clear());
      _showMsg(lang == VoiceLang.bengali ? '🗑️ সব বাতিল' : '🗑️ Cart cleared');
      return;
    }

    if (parsed.isTotalCommand) {
      if (_cartItems.isNotEmpty) _showCheckout();
      return;
    }

    final item = VoiceService.matchToProduct(parsed, _allProducts);
    if (item != null) {
      if (parsed.isRemoveCommand) {
        setState(() => _cartItems.removeWhere((i) => i.productId == item.productId));
        _showMsg('❌ সরানো হয়েছে');
      } else {
        _addAdHocItem(item);
        _showMsg(lang == VoiceLang.bengali
            ? '✅ ${item.nameBn ?? item.name} যোগ হয়েছে'
            : '✅ ${item.name} added');
      }
    } else {
      _showMsg(lang == VoiceLang.bengali ? '❓ বুঝতে পারিনি' : '❓ Not understood');
    }
  }

  void _showMsg(String msg) {
    setState(() => _voiceMessage = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _voiceMessage = '');
    });
  }

  // ─── Checkout ─────────────────────────────────────────────────
  double get _subtotal => _cartItems.fold(0, (s, i) => s + i.total);
  double get _tax => (_subtotal - _discount) * (widget.settings.taxRate / 100);
  double get _total => _subtotal - _discount + _tax;

  void _showCheckout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(
        subtotal: _subtotal,
        discount: _discount,
        tax: _tax,
        total: _total,
        currency: widget.settings.currency,
        taxRate: widget.settings.taxRate,
        onDiscountChanged: (v) => setState(() => _discount = v),
        onPaymentChanged: (v) => setState(() => _paymentMode = v),
        paymentMode: _paymentMode,
        onConfirm: _saveBill,
      ),
    );
  }

  Future<void> _saveBill({String? customerName, String? customerPhone, String? notes}) async {
    final bill = Bill(
      billNumber: BillUtils.generateBillNumber(),
      items: _cartItems,
      subtotal: _subtotal,
      discount: _discount,
      tax: _tax,
      total: _total,
      customerName: customerName,
      customerPhone: customerPhone,
      paymentMode: PaymentModeExt.fromString(_paymentMode),
      notes: notes,
    );
    final id = await DatabaseService.instance.insertBill(bill);
    setState(() {
      _savedBill = Bill(
        id: id,
        billNumber: bill.billNumber,
        items: bill.items,
        subtotal: bill.subtotal,
        discount: bill.discount,
        tax: bill.tax,
        total: bill.total,
        customerName: customerName,
        customerPhone: customerPhone,
        paymentMode: bill.paymentMode,
        notes: notes,
      );
      _billSuccess = true;
    });
    if (context.mounted) Navigator.pop(context); // Close sheet
  }

  Future<void> _handlePdf(String action) async {
    if (_savedBill == null) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await PdfService.generateBillPdf(_savedBill!, widget.settings);
      if (action == 'share') {
        await PdfService.sharePdf(bytes, _savedBill!.billNumber, widget.settings.shopName);
      } else {
        await PdfService.printPdf(bytes);
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  void _resetBill() {
    setState(() {
      _cartItems.clear();
      _discount = 0;
      _paymentMode = 'cash';
      _billSuccess = false;
      _savedBill = null;
      _voiceTranscript = '';
    });
  }

  // ─── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_billSuccess) return _buildSuccessScreen();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text('নতুন বিল / New Bill'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_cartItems.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _cartItems.clear()),
              icon: const Icon(Icons.clear_all, color: Colors.white70, size: 18),
              label: const Text('Clear', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Voice + Search bar
          Container(
            color: const Color(0xFF2E7D32),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _search,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'পণ্য খুঁজুন...',
                      hintStyle: TextStyle(color: Colors.green[200]),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.green[200]),
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
                const SizedBox(width: 8),
                // Voice button
                GestureDetector(
                  onTap: _toggleVoice,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors.red
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Language toggle
                GestureDetector(
                  onTap: () => setState(() {
                    _voiceLang = _voiceLang == VoiceLang.bengali
                        ? VoiceLang.english
                        : VoiceLang.bengali;
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _voiceLang == VoiceLang.bengali ? 'বাং' : 'EN',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Voice feedback
          if (_voiceTranscript.isNotEmpty || _voiceMessage.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFE8F5E9),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_voiceTranscript.isNotEmpty)
                    Text('🎤 "$_voiceTranscript"',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54)),
                  if (_voiceMessage.isNotEmpty)
                    Text(_voiceMessage,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B5E20))),
                ],
              ),
            ),

          // Main area: products + cart split
          Expanded(
            child: Row(
              children: [
                // Products grid
                Expanded(
                  flex: 6,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (_, i) {
                      final p = _filteredProducts[i];
                      return GestureDetector(
                        onTap: () => _addToCart(p),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: Colors.grey.shade200),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                p.nameBn ?? p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (p.nameBn != null)
                                Text(p.name,
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 10)),
                              const Spacer(),
                              Text(
                                '${widget.settings.currency}${p.price}',
                                style: const TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              Text('/${p.unit}',
                                  style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Cart sidebar
                Container(
                  width: 180,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        left: BorderSide(color: Color(0xFFE0E0E0))),
                  ),
                  child: Column(
                    children: [
                      // Cart header
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: const Color(0xFFF1F8F1),
                        child: Row(
                          children: [
                            const Icon(Icons.shopping_cart,
                                color: Color(0xFF2E7D32), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'বিল (${_cartItems.length})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                      // Cart items
                      Expanded(
                        child: _cartItems.isEmpty
                            ? Center(
                                child: Text(
                                  'বিল খালি',
                                  style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(6),
                                itemCount: _cartItems.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final item = _cartItems[i];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.nameBn ?? item.name,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _removeItem(i),
                                              child: const Icon(Icons.close,
                                                  size: 14,
                                                  color: Colors.red),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () =>
                                                  _updateQty(i, -1),
                                              child: Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          6),
                                                ),
                                                child: const Icon(
                                                    Icons.remove,
                                                    size: 12),
                                              ),
                                            ),
                                            Expanded(
                                              child: Center(
                                                child: Text(
                                                  '${item.quantity}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () =>
                                                  _updateQty(i, 1),
                                              child: Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                      0xFFE8F5E9),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          6),
                                                ),
                                                child: const Icon(
                                                  Icons.add,
                                                  size: 12,
                                                  color: Color(0xFF2E7D32),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${widget.settings.currency}${item.total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),

                      // Total + Checkout
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          border: Border(
                              top: BorderSide(color: Color(0xFFE0E0E0))),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('মোট:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(
                                  '${widget.settings.currency}${_total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _cartItems.isEmpty
                                    ? null
                                    : _showCheckout,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                ),
                                child: const Text('বিল করুন',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text('বিল সফল!'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF2E7D32), size: 60),
              ),
              const SizedBox(height: 20),
              const Text('বিল সফলভাবে সেভ হয়েছে!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20))),
              const SizedBox(height: 8),
              Text('Bill: ${_savedBill?.billNumber ?? ''}',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text(
                '${widget.settings.currency}${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B5E20),
                    letterSpacing: -1),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _generatingPdf ? null : () => _handlePdf('share'),
                      icon: const Icon(Icons.share),
                      label: const Text('শেয়ার করুন'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2E7D32),
                        side: const BorderSide(color: Color(0xFF2E7D32)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generatingPdf ? null : () => _handlePdf('print'),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF প্রিন্ট'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _resetBill,
                  child: const Text('নতুন বিল শুরু করুন',
                      style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Checkout Bottom Sheet ──────────────────────────────────────
class _CheckoutSheet extends StatefulWidget {
  final double subtotal, discount, tax, total, taxRate;
  final String currency, paymentMode;
  final ValueChanged<double> onDiscountChanged;
  final ValueChanged<String> onPaymentChanged;
  final Future<void> Function({String? customerName, String? customerPhone, String? notes}) onConfirm;

  const _CheckoutSheet({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.taxRate,
    required this.currency,
    required this.paymentMode,
    required this.onDiscountChanged,
    required this.onPaymentChanged,
    required this.onConfirm,
  });

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _payment = 'cash';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _payment = widget.paymentMode;
    _discountCtrl.text = widget.discount > 0 ? widget.discount.toString() : '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payments = [
      ('cash', 'নগদ'),
      ('upi', 'UPI'),
      ('card', 'কার্ড'),
      ('credit', 'বাকি'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('চেকআউট / Checkout',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _field(_nameCtrl, 'Customer Name (optional)', Icons.person_outline),
            const SizedBox(height: 10),
            _field(_phoneCtrl, 'Phone (optional)', Icons.phone_outlined,
                type: TextInputType.phone),
            const SizedBox(height: 10),
            _field(_discountCtrl, 'Discount (${widget.currency})',
                Icons.discount_outlined,
                type: TextInputType.number,
                onChanged: (v) =>
                    widget.onDiscountChanged(double.tryParse(v) ?? 0)),
            const SizedBox(height: 14),
            const Text('Payment Mode', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: payments.map((p) {
                final selected = _payment == p.$1;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _payment = p.$1);
                      widget.onPaymentChanged(p.$1);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        p.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _summaryRow('Subtotal', '${widget.currency}${widget.subtotal.toStringAsFixed(2)}'),
                  if (widget.discount > 0)
                    _summaryRow('Discount', '-${widget.currency}${widget.discount.toStringAsFixed(2)}',
                        color: Colors.orange),
                  if (widget.tax > 0)
                    _summaryRow('Tax (${widget.taxRate}%)',
                        '+${widget.currency}${widget.tax.toStringAsFixed(2)}'),
                  const Divider(),
                  _summaryRow(
                    'মোট Total',
                    '${widget.currency}${widget.total.toStringAsFixed(2)}',
                    bold: true,
                    color: const Color(0xFF1B5E20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await widget.onConfirm(
                        customerName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
                        customerPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
                        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('বিল সেভ করুন',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        ),
      );

  Widget _summaryRow(String label, String value,
          {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                    color: color ?? Colors.grey[700])),
            Text(value,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 15 : 13,
                    color: color ?? Colors.grey[800])),
          ],
        ),
      );
}
