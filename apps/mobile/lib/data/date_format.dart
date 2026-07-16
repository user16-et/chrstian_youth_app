// Shared, user-facing date formatting used across feature screens, so the app
// never shows a raw ISO string or an unparseable locale date.

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
];

/// "Jun 22, 2026 · 4:29 PM" (or just the date when there is no time-of-day).
/// Falls back to the raw value when it can't be parsed.
String friendlyDateTime(String raw) {
  final dt = DateTime.tryParse(raw)?.toLocal();
  if (dt == null) return raw.trim();
  final date = '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
  if (dt.hour == 0 && dt.minute == 0) return date;
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final ap = dt.hour < 12 ? 'AM' : 'PM';
  return '$date · $h:${dt.minute.toString().padLeft(2, '0')} $ap';
}

/// "Jun 22, 2026". Falls back to the first 10 characters, then the raw value.
String friendlyDate(String raw) {
  if (raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw)?.toLocal();
  if (dt == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

/// Compact relative time: "now", "5m", "3h", "2d", then "Jun 22" for older.
String relativeTime(String raw) {
  final dt = DateTime.tryParse(raw)?.toLocal();
  if (dt == null) return raw.trim();
  final diff = DateTime.now().difference(dt);
  if (diff.isNegative || diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${_months[dt.month - 1]} ${dt.day}';
}
