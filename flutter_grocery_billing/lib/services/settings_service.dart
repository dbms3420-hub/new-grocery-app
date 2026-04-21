import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const String _prefix = 'setting_';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = AppSettings().toPrefsMap().keys;
    final map = <String, String?>{
      for (final k in keys) k: prefs.getString('$_prefix$k'),
    };
    return AppSettings.fromPrefsMap(map);
  }

  static Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in settings.toPrefsMap().entries) {
      await prefs.setString('$_prefix${entry.key}', entry.value);
    }
  }
}
