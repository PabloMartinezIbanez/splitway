import 'package:flutter/material.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitway_mobile/src/features/settings/settings_screen.dart';
import 'package:splitway_mobile/src/services/locale/locale_controller.dart';

Widget _harness(LocaleController controller) {
  return ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      locale: controller.locale,
      supportedLocales: LocaleController.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SettingsScreen(localeController: controller),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows both language options and marks current', (tester) async {
    final ctrl = await LocaleController.load(deviceLocale: const Locale('es'));
    await tester.pumpWidget(_harness(ctrl));
    await tester.pumpAndSettle();

    expect(find.text('Español'), findsOneWidget);
    expect(find.text('Inglés'), findsOneWidget);

    final spanishTile = tester.widget<RadioListTile<Locale>>(
      find.byWidgetPredicate(
        (w) => w is RadioListTile<Locale> && w.value == const Locale('es'),
      ),
    );
    expect(spanishTile.groupValue, const Locale('es'));
  });

  testWidgets('tapping English switches locale and updates UI', (tester) async {
    final ctrl = await LocaleController.load(deviceLocale: const Locale('es'));
    await tester.pumpWidget(_harness(ctrl));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inglés'));
    await tester.pumpAndSettle();

    expect(ctrl.locale, const Locale('en'));
    // After switching, the screen title is now in English ("Settings").
    expect(find.text('Settings'), findsOneWidget);
  });
}
