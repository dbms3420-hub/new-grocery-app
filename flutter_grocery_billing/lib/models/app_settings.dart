class AppSettings {
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String shopEmail;
  final String gstNumber;
  final String currency;
  final double taxRate;
  final String defaultLanguage; // 'bn' or 'en'
  final String tagline1;
  final String tagline2;
  final String footerNote;

  const AppSettings({
    this.shopName = 'আমার দোকান',
    this.shopAddress = 'ঠিকানা লিখুন',
    this.shopPhone = '০১XXXXXXXXX',
    this.shopEmail = '',
    this.gstNumber = '',
    this.currency = '₹',
    this.taxRate = 0,
    this.defaultLanguage = 'en',
    this.tagline1 = 'ধন্যবাদ আমাদের দোকানে আসার জন্য',
    this.tagline2 = 'আবার আসবেন, ভালো থাকবেন',
    this.footerNote = 'এই বিল কম্পিউটার দ্বারা তৈরি, কোনো স্বাক্ষরের প্রয়োজন নেই',
  });

  AppSettings copyWith({
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? shopEmail,
    String? gstNumber,
    String? currency,
    double? taxRate,
    String? defaultLanguage,
    String? tagline1,
    String? tagline2,
    String? footerNote,
  }) =>
      AppSettings(
        shopName: shopName ?? this.shopName,
        shopAddress: shopAddress ?? this.shopAddress,
        shopPhone: shopPhone ?? this.shopPhone,
        shopEmail: shopEmail ?? this.shopEmail,
        gstNumber: gstNumber ?? this.gstNumber,
        currency: currency ?? this.currency,
        taxRate: taxRate ?? this.taxRate,
        defaultLanguage: defaultLanguage ?? this.defaultLanguage,
        tagline1: tagline1 ?? this.tagline1,
        tagline2: tagline2 ?? this.tagline2,
        footerNote: footerNote ?? this.footerNote,
      );

  Map<String, String> toPrefsMap() => {
        'shop_name': shopName,
        'shop_address': shopAddress,
        'shop_phone': shopPhone,
        'shop_email': shopEmail,
        'gst_number': gstNumber,
        'currency': currency,
        'tax_rate': taxRate.toString(),
        'default_language': defaultLanguage,
        'tagline1': tagline1,
        'tagline2': tagline2,
        'footer_note': footerNote,
      };

  factory AppSettings.fromPrefsMap(Map<String, String?> map) => AppSettings(
        shopName: map['shop_name'] ?? 'আমার দোকান',
        shopAddress: map['shop_address'] ?? 'ঠিকানা লিখুন',
        shopPhone: map['shop_phone'] ?? '০১XXXXXXXXX',
        shopEmail: map['shop_email'] ?? '',
        gstNumber: map['gst_number'] ?? '',
        currency: map['currency'] ?? '৳',
        taxRate: double.tryParse(map['tax_rate'] ?? '0') ?? 0,
        defaultLanguage: map['default_language'] ?? 'bn',
        tagline1: map['tagline1'] ?? 'ধন্যবাদ আমাদের দোকানে আসার জন্য',
        tagline2: map['tagline2'] ?? 'আবার আসবেন, ভালো থাকবেন',
        footerNote: map['footer_note'] ??
            'এই বিল কম্পিউটার দ্বারা তৈরি, কোনো স্বাক্ষরের প্রয়োজন নেই',
      );
}
