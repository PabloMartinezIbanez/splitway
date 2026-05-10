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

  static String distanceMeters(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  static String speedMps(double mps) {
    final kmh = mps * 3.6;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  static String dateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy · HH:mm', 'es_ES').format(dt);
  }
}
