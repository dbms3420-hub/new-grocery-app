import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSaved;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;
  bool _saved = false;

  final Map<String, TextEditingController> _ctrl = {};

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    final fields = {
      'shopName': _settings.shopName,
      'shopAddress': _settings.shopAddress,
      'shopPhone': _settings.shopPhone,
      'shopEmail': _settings.shopEmail,
      'gstNumber': _settings.gstNumber,
      'currency': _settings.currency,
      'taxRate': _settings.taxRate.toString(),
      'tagline1': _settings.tagline1,
      'tagline2': _settings.tagline2,
      'footerNote': _settings.footerNote,
    };
    for (final e in fields.entries) {
      _ctrl[e.key] = TextEditingController(text: e.value);
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _settings = _settings.copyWith(
      shopName: _ctrl['shopName']!.text,
      shopAddress: _ctrl['shopAddress']!.text,
      shopPhone: _ctrl['shopPhone']!.text,
      shopEmail: _ctrl['shopEmail']!.text,
      gstNumber: _ctrl['gstNumber']!.text,
      currency: _ctrl['currency']!.text,
      taxRate: double.tryParse(_ctrl['taxRate']!.text) ?? 0,
      tagline1: _ctrl['tagline1']!.text,
      tagline2: _ctrl['tagline2']!.text,
      footerNote: _ctrl['footerNote']!.text,
    );
    await SettingsService.save(_settings);
    widget.onSaved();
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text('সেটিংস'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('🏪 দোকানের তথ্য', [
            _field('shopName', 'দোকানের নাম'),
            _field('shopAddress', 'ঠিকানা'),
            _field('shopPhone', 'ফোন নম্বর', type: TextInputType.phone),
            _field('shopEmail', 'Email (optional)', type: TextInputType.emailAddress),
            _field('gstNumber', 'GST / GSTIN (optional)'),
          ]),

          _section('💰 বিলিং সেটিংস', [
            _field('currency', 'Currency Symbol (৳, ₹, \$)'),
            _field('taxRate', 'Tax Rate (%)', type: TextInputType.number),
          ]),

          _section('📄 PDF বিলের তথ্য (কাস্টমাইজ করুন)', [
            _field('tagline1', 'Tagline 1 (বিলের নিচে)'),
            _field('tagline2', 'Tagline 2'),
            _field('footerNote', 'Footer Note'),
          ]),

          _section('🎤 ভয়েস সেটিংস', [
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ডিফল্ট ভাষা', style: TextStyle(fontSize: 14)),
                DropdownButton<String>(
                  value: _settings.defaultLanguage,
                  onChanged: (v) => setState(() {
                    _settings = _settings.copyWith(defaultLanguage: v);
                  }),
                  items: const [
                    DropdownMenuItem(value: 'bn', child: Text('বাংলা (Bengali)')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ভয়েস কমান্ড:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 6),
                  Text('• "চাল ৬৫" → চাল যোগ, দাম ৳৬৫', style: TextStyle(fontSize: 12)),
                  Text('• "তেল ২ লিটার ১৮০" → তেল ২ লিটার, ৳১৮০', style: TextStyle(fontSize: 12)),
                  Text('• "মোট দেখাও" → চেকআউট খুলুন', style: TextStyle(fontSize: 12)),
                  Text('• "সব বাতিল" → কার্ট খালি করুন', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('💡 শেষ সংখ্যা = দাম, আগের শব্দ = পণ্যের নাম',
                      style: TextStyle(fontSize: 11, color: Colors.green, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _saved ? Colors.green[700] : const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              _saved ? '✅ সেভ হয়েছে!' : 'সেটিংস সেভ করুন',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: children
                  .map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: w,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _field(String key, String label, {TextInputType type = TextInputType.text}) =>
      TextField(
        controller: _ctrl[key],
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        ),
      );
}
