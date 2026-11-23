import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _rupee = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _time = DateFormat('h:mm a');
  static final _day = DateFormat('EEEE, d MMM');

  static String rupees(num v) => _rupee.format(v);

  static String km(double km) => km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';

  static String duration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds} sec';
    if (d.inHours < 1) return '${d.inMinutes} min';
    final m = d.inMinutes % 60;
    return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
  }

  /// "1 hr 24 mins", for sentences.
  static String durationLong(Duration d) {
    final minutes = d.inMinutes;
    if (minutes < 1) return 'under a minute';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hours = h == 0 ? '' : '$h hr';
    final mins = m == 0 ? '' : '$m ${m == 1 ? 'min' : 'mins'}';
    return [hours, mins].where((s) => s.isNotEmpty).join(' ');
  }

  /// "8:45 AM" from minutes after midnight.
  static String minuteOfDay(int minutes) =>
      _time.format(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));

  static String time(DateTime d) => _time.format(d);

  static String dayHeading(DateTime d, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return _day.format(d);
  }

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }
}
