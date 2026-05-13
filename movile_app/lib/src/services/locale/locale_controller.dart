import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mutable, listenable holder for the current app [Locale].
///
/// Persists the choice in [SharedPreferences] under the key `locale` as the
/// language code (`"en"` / `"es"`). On first launch, falls back to the device
/// locale if it is supported, otherwise to Spanish.
class LocaleController extends ChangeNotifier {
  LocaleController._(this._locale, this._prefs);

  static const String _prefsKey = 'locale';
  static const List<Locale> supported = [Locale('es'), Locale('en')];

  static const Locale _fallback = Locale('es');

  Locale _locale;
  final SharedPreferences _prefs;

  Locale get locale => _locale;

  static Future<LocaleController> load({required Locale deviceLocale}) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    final resolved = _resolve(stored, deviceLocale);
    Intl.defaultLocale = resolved.toLanguageTag();
    return LocaleController._(resolved, prefs);
  }

  static Locale _resolve(String? stored, Locale deviceLocale) {
    if (stored != null) {
      for (final l in supported) {
        if (l.languageCode == stored) return l;
      }
    }
    for (final l in supported) {
      if (l.languageCode == deviceLocale.languageCode) return l;
    }
    return _fallback;
  }

  Future<void> setLocale(Locale next) async {
    if (next == _locale) return;
    _locale = next;
    Intl.defaultLocale = next.toLanguageTag();
    await _prefs.setString(_prefsKey, next.languageCode);
    notifyListeners();
  }
}
