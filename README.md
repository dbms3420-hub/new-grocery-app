flutter_grocery_billing/README.md
Offline grocery billing app with Bengali/English voice support.

## Setup Instructions

### Step 1 — Install Flutter
Download from https://flutter.dev/docs/get-started/install
(Choose Android for best compatibility)

### Step 2 — Open Project
```bash
cd flutter_grocery_billing
flutter pub get
```

### Step 3 — Add Your Assets

**Shop Logo:**
- Place your logo at: `assets/images/shop_logo.png`
- Recommended: 512×512 px, transparent background PNG
- This becomes your PDF header AND your app icon

**Bengali Font:**
- Download NotoSansBengali from: https://fonts.google.com/noto/specimen/Noto+Sans+Bengali
- Place files at:
  - `assets/fonts/NotoSansBengali-Regular.ttf`
  - `assets/fonts/NotoSansBengali-Bold.ttf`

### Step 4 — Generate App Icon
```bash
flutter pub run flutter_launcher_icons
```

### Step 5 — Run on Android
```bash
flutter run
```

Or build APK:
```bash
flutter build apk --release
```

APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

---

## Features

- ✅ **100% Offline** — SQLite database, no internet needed
- ✅ **Bengali + English Voice** — auto-detect language
- ✅ **Voice Parser** — last number = price, words before = product name
- ✅ **PDF Bills** — custom logo, Bengali taglines, share via WhatsApp/Email
- ✅ **Only 2 Tabs** — Home + History (no Khata, no Business Insights)
- ✅ **Custom App Icon** — from your shop logo

## Voice Command Examples

| Say (Bengali) | Action |
|---|---|
| "চাল ৬৫" | Add চাল at ৳65 |
| "তেল ২ লিটার ১৮০" | Add তেল, 2 liters, ৳180 |
| "মোট দেখাও" | Open checkout |
| "সব বাতিল" | Clear cart |

| Say (English) | Action |
|---|---|
| "Rice 65" | Add Rice at ৳65 |
| "Oil 2 liter 180" | Add Oil, 2L, ৳180 |
| "total" | Open checkout |
| "cancel" | Clear cart |

## Customise PDF Taglines
Go to Settings → change Tagline 1, Tagline 2, Footer Note

## File Structure
```
lib/
├── main.dart              # App entry point, 2-tab shell
├── models/
│   ├── product.dart
│   ├── bill.dart
│   ├── bill_item.dart
│   └── app_settings.dart
├── services/
│   ├── database_service.dart   # SQLite (sqflite)
│   ├── voice_service.dart      # Voice + Regex parser
│   ├── pdf_service.dart        # PDF generation + share
│   └── settings_service.dart   # SharedPreferences
├── screens/
│   ├── home_screen.dart        # Dashboard
│   ├── billing_screen.dart     # Billing + voice
│   ├── history_screen.dart     # Bill history
│   ├── products_screen.dart    # Product management
│   └── settings_screen.dart    # Shop settings
└── utils/
    └── bill_utils.dart
```
