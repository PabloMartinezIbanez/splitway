import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String duration(Duration d) {
    final ms = d.inMilliseconds;
    if (ms < 0) return '--:--.---';
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final millis = ms % 1000;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }

  /// Returns just the numeric portion. The caller wraps it with the localized
  /// unit using `AppLocalizations.unitMeters` / `unitKilometers`.
  static (double value, bool isKilometers) distanceMeters(double meters) {
    if (meters < 1000) return (meters, false);
    return (meters / 1000, true);
  }

  /// Returns just the numeric portion in km/h. The caller wraps it with
  /// `AppLocalizations.unitKmh`.
  static double speedMps(double mps) => mps * 3.6;

  /// Uses `Intl.defaultLocale` set by `LocaleController`.
  static String dateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy · HH:mm').format(dt);
  }
}
