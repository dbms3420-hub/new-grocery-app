import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/product.dart';
import '../models/bill_item.dart';

enum VoiceLang { bengali, english, auto }

class VoiceParseResult {
  final String? productName;
  final double? price;
  final double quantity;
  final bool isCancelCommand;
  final bool isTotalCommand;
  final bool isRemoveCommand;
  final String rawText;
  final VoiceLang detectedLang;

  const VoiceParseResult({
    this.productName,
    this.price,
    this.quantity = 1.0,
    this.isCancelCommand = false,
    this.isTotalCommand = false,
    this.isRemoveCommand = false,
    required this.rawText,
    required this.detectedLang,
  });
}

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  // Unicode range for Bengali characters: U+0980 to U+09FF
  static final RegExp _bengaliRegex = RegExp(r'[\u0980-\u09FF]');

  // Last number in transcript = price (your spec)
  // Everything before the last number = product name
  static final RegExp _lastNumberRegex = RegExp(r'^(.*?)\s+(\d+(?:\.\d+)?)\s*$');

  // Quantity patterns (Bengali + English)
  static final RegExp _quantityRegex = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:কেজি|kg|গ্রাম|gram|g|লিটার|liter|l|পিস|piece|pcs|টি|ta|টা)',
    caseSensitive: false,
  );

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  // ─── Init ──────────────────────────────────────────────────────
  Future<bool> initialize() async {
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) return false;

    _isInitialized = await _stt.initialize(
      onError: (error) => _isListening = false,
      debugLogging: false,
    );
    return _isInitialized;
  }

  // ─── Language Detection ────────────────────────────────────────
  static VoiceLang detectLanguage(String text) {
    if (_bengaliRegex.hasMatch(text)) return VoiceLang.bengali;
    return VoiceLang.english;
  }

  // ─── Parse Voice Transcript ────────────────────────────────────
  /// Core Parser:
  /// - Last number spoken = price
  /// - Everything before the last number = product name (Bengali or English)
  /// - Optional quantity extracted if unit keyword present
  static VoiceParseResult parseTranscript(String transcript) {
    final text = transcript.trim();
    final lang = detectLanguage(text);
    final lower = text.toLowerCase();

    // Cancel commands
    final cancelKw = ['বাতিল', 'ক্লিয়ার', 'মুছে', 'রিসেট', 'cancel', 'clear', 'reset'];
    if (cancelKw.any((k) => lower.contains(k))) {
      return VoiceParseResult(rawText: text, detectedLang: lang, isCancelCommand: true);
    }

    // Total / checkout commands
    final totalKw = ['মোট', 'সর্বমোট', 'টোটাল', 'শেষ', 'total', 'checkout', 'done', 'finish'];
    if (totalKw.any((k) => lower.contains(k))) {
      return VoiceParseResult(rawText: text, detectedLang: lang, isTotalCommand: true);
    }

    // Remove commands
    final removeKw = ['বাদ', 'সরাও', 'মুছো', 'কম', 'remove', 'delete', 'minus'];
    final isRemove = removeKw.any((k) => lower.contains(k));

    // Extract quantity if unit keyword is present
    double quantity = 1.0;
    String cleanText = text;
    final qtyMatch = _quantityRegex.firstMatch(text);
    if (qtyMatch != null) {
      quantity = double.tryParse(qtyMatch.group(1) ?? '1') ?? 1.0;
      cleanText = text.replaceFirst(qtyMatch.group(0) ?? '', '').trim();
    }

    // Core parser: last number = price, everything before = name
    final match = _lastNumberRegex.firstMatch(cleanText);
    if (match != null) {
      final namePart = match.group(1)?.trim() ?? '';
      final pricePart = double.tryParse(match.group(2) ?? '');

      if (namePart.isNotEmpty && pricePart != null) {
        return VoiceParseResult(
          productName: namePart,
          price: pricePart,
          quantity: quantity,
          isRemoveCommand: isRemove,
          rawText: text,
          detectedLang: lang,
        );
      }
    }

    // Fallback: try to find a number anywhere
    final numbers = RegExp(r'\d+(?:\.\d+)?').allMatches(cleanText).toList();
    if (numbers.isNotEmpty) {
      final lastNum = double.tryParse(numbers.last.group(0)!);
      final beforeNum = cleanText.substring(0, numbers.last.start).trim();
      if (beforeNum.isNotEmpty && lastNum != null) {
        return VoiceParseResult(
          productName: beforeNum,
          price: lastNum,
          quantity: quantity,
          isRemoveCommand: isRemove,
          rawText: text,
          detectedLang: lang,
        );
      }
    }

    return VoiceParseResult(rawText: text, detectedLang: lang);
  }

  /// Match parsed voice result to existing products or create ad-hoc item
  static BillItem? matchToProduct(
    VoiceParseResult parsed,
    List<Product> products,
  ) {
    if (parsed.productName == null) return null;

    final query = parsed.productName!.toLowerCase();

    // Try to find matching product
    Product? matched;
    for (final p in products) {
      if (p.name.toLowerCase().contains(query) ||
          (p.nameBn != null && p.nameBn!.contains(parsed.productName!))) {
        matched = p;
        break;
      }
    }

    if (matched != null) {
      return BillItem(
        productId: matched.id,
        name: matched.name,
        nameBn: matched.nameBn,
        price: parsed.price ?? matched.price,
        quantity: parsed.quantity,
        unit: matched.unit,
      );
    }

    // Ad-hoc item from voice (not in product list)
    if (parsed.price != null) {
      return BillItem(
        name: parsed.productName!,
        nameBn: parsed.detectedLang == VoiceLang.bengali ? parsed.productName : null,
        price: parsed.price!,
        quantity: parsed.quantity,
        unit: 'piece',
      );
    }

    return null;
  }

  // ─── Start Listening ───────────────────────────────────────────
  Future<void> startListening({
    required VoiceLang lang,
    required void Function(String transcript, bool isFinal) onResult,
    required void Function(String error) onError,
  }) async {
    if (!_isInitialized || _isListening) return;

    final localeId = lang == VoiceLang.english ? 'en_IN' : 'bn_BD';

    _isListening = true;
    await _stt.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
        if (result.finalResult) _isListening = false;
      },
      localeId: localeId,
      listenMode: ListenMode.dictation,
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    await _stt.stop();
    _isListening = false;
  }

  Future<void> cancelListening() async {
    await _stt.cancel();
    _isListening = false;
  }

  // ─── Available Locales ─────────────────────────────────────────
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) return [];
    return _stt.locales();
  }
}
