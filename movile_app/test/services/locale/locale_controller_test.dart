import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitway_mobile/src/services/locale/locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to device locale when no preference stored', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final ctrl = await LocaleController.load(
      deviceLocale: const Locale('en'),
    );
    expect(ctrl.locale, const Locale('en'));
    debugDefaultTargetPlatformOverride = null;
  });

  test('falls back to Spanish for unsupported device locale', () async {
    final ctrl = await LocaleController.load(
      deviceLocale: const Locale('fr'),
    );
    expect(ctrl.locale, const Locale('es'));
  });

  test('loads stored preference', () async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final ctrl = await LocaleController.load(
      deviceLocale: const Locale('es'),
    );
    expect(ctrl.locale, const Locale('en'));
  });

  test('setLocale persists and notifies listeners', () async {
    final ctrl = await LocaleController.load(
      deviceLocale: const Locale('es'),
    );
    var notified = 0;
    ctrl.addListener(() => notified += 1);

    await ctrl.setLocale(const Locale('en'));

    expect(ctrl.locale, const Locale('en'));
    expect(notified, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), 'en');
  });

  test('setLocale skips notify when value is unchanged', () async {
    final ctrl = await LocaleController.load(
      deviceLocale: const Locale('es'),
    );
    var notified = 0;
    ctrl.addListener(() => notified += 1);

    await ctrl.setLocale(const Locale('es'));

    expect(notified, 0);
  });
}
