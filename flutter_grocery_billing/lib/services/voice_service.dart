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

  static final RegExp _bengaliRegex = RegExp(r'[\u0980-\u09FF]');
  static final RegExp _lastNumberRegex = RegExp(r'^(.*?)\s+(\d+(?:\.\d+)?)\s*$');
  static final RegExp _quantityRegex = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:কেজি|kg|গ্রাম|gram|g|লিটার|liter|l|পিস|piece|pcs|টি|ta|টা)',
    caseSensitive: false,
  );

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  Future<bool> initialize() async {
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) return false;

    _isInitialized = await _stt.initialize(
      onError: (error) => _isListening = false,
      debugLogging: false,
    );
    return _isInitialized;
  }

  static VoiceLang detectLanguage(String text) {
    if (_bengaliRegex.hasMatch(text)) return VoiceLang.bengali;
    return VoiceLang.english;
  }

  static VoiceParseResult parseTranscript(String transcript) {
    final text = transcript.trim();
    final lang = detectLanguage(text);
    final lower = text.toLowerCase();

    final cancelKw = ['বাতিল', 'ক্লিয়ার', 'মুছে', 'রিসেট', 'cancel', 'clear', 'reset'];
    if (cancelKw.any((k) => lower.contains(k))) {
      return VoiceParseResult(rawText: text, detectedLang: lang, isCancelCommand: true);
    }

    final totalKw = ['মোট', 'সর্বমোট', 'টোটাল', 'শেষ', 'total', 'checkout', 'done', 'finish'];
    if (totalKw.any((k) => lower.contains(k))) {
      return VoiceParseResult(rawText: text, detectedLang: lang, isTotalCommand: true);
    }

    final removeKw = ['বাদ', 'সরাও', 'মুছো', 'কম', 'remove', 'delete', 'minus'];
    final isRemove = removeKw.any((k) => lower.contains(k));

    double quantity = 1.0;
    String cleanText = text;
    final qtyMatch = _quantityRegex.firstMatch(text);
    if (qtyMatch != null) {
      quantity = double.tryParse(qtyMatch.group(1) ?? '1') ?? 1.0;
      cleanText = text.replaceFirst(qtyMatch.group(0) ?? '', '').trim();
    }

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

  static BillItem? matchToProduct(VoiceParseResult parsed, List<Product> products) {
    if (parsed.productName == null) return null;

    final query = parsed.productName!.toLowerCase();
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
      listenOptions: SpeechListenOptions(   // ✅ fixed
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
      ),
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

  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) return [];
    return _stt.locales();
  }
}
