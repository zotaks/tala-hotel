/// Small date / money helpers (no extra packages needed).
const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _wdLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _moLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime today() => dateOnly(DateTime.now());
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _pad2(int n) => n.toString().padLeft(2, '0');
String ymd(DateTime d) => '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';
DateTime parseYmd(String s) {
  final p = s.split(' ').first.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime parseDateTime(String s) => DateTime.tryParse(s.replaceFirst(' ', 'T')) ?? DateTime.now();

String wd(DateTime d) => _wd[d.weekday - 1];
String wdLong(DateTime d) => _wdLong[d.weekday - 1];
String mon(DateTime d) => _mo[d.month - 1];
String monLong(DateTime d) => _moLong[d.month - 1];

/// Sat, Nov 7
String fmtDay(DateTime d) => '${wd(d)}, ${mon(d)} ${d.day}';

/// Nov 7
String fmtShort(DateTime d) => '${mon(d)} ${d.day}';

/// Oct 12, 2026
String fmtFull(DateTime d) => '${mon(d)} ${d.day}, ${d.year}';

/// Friday, October 30
String fmtLong(DateTime d) => '${wdLong(d)}, ${monLong(d)} ${d.day}';

/// "Today", "Tomorrow", "Sat, Nov 7"
String fmtRelative(DateTime d) {
  final diff = daysBetween(today(), d);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return fmtDay(d);
}

/// ₱3,450 (decimals only when needed)
String peso(num v) {
  final neg = v < 0;
  final whole = v.abs().floor();
  final cents = ((v.abs() - whole) * 100).round();
  final s = whole.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}₱$b${cents > 0 ? '.${_pad2(cents)}' : ''}';
}

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String firstName(String name) => name.trim().split(' ').first;

/// Type-safe clamp for ints (avoids num/int typing surprises).
int clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

/// 9:02 PM
String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${_pad2(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "Today, 9:02 PM" · "Yesterday, 8:15 AM" · "Oct 30, 4:40 PM" — from a "YYYY-MM-DD HH:MM:SS" stamp.
String fmtStamp(String? stamp) {
  if (stamp == null || stamp.isEmpty) return 'Never';
  final d = parseDateTime(stamp);
  final diff = daysBetween(d, today());
  final day = diff == 0 ? 'Today' : (diff == 1 ? 'Yesterday' : fmtShort(d));
  return '$day, ${fmtTime(d)}';
}
