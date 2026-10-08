import 'package:intl/intl.dart';

/// Centralized Date and Time parsing, conversion, and formatting utility for Simple ADVT.
/// Ensures consistent UTC parsing from backend APIs and conversion to device local timezone for display.
class DateTimeUtils {
  static final DateFormat defaultDateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat defaultDateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat defaultTimeFormat = DateFormat('hh:mm a');

  /// Parse any server timestamp into a timezone-aware UTC DateTime object.
  static DateTime? parseUtc(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return null;

    try {
      // If it ends with Z or has timezone offset like +05:30 or -04:00
      if (str.endsWith('Z') || str.endsWith('z')) {
        return DateTime.parse(str).toUtc();
      }
      if (str.contains('+') || (str.contains('-') && str.lastIndexOf('-') > 10)) {
        return DateTime.parse(str).toUtc();
      }
      // If raw MySQL string '2026-10-08 03:40:00' without timezone, treat as UTC
      final formatted = str.contains('T') ? '${str}Z' : '${str.replaceAll(' ', 'T')}Z';
      return DateTime.parse(formatted).toUtc();
    } catch (_) {
      try {
        return DateTime.parse(str).toUtc();
      } catch (_) {
        return null;
      }
    }
  }

  /// Formats UTC or local DateTime into user's local display format: '08 Oct 2026, 09:10 AM'
  static String formatDateTime(DateTime? dateTime, {String? placeholder}) {
    if (dateTime == null) return placeholder ?? '';
    final local = dateTime.toLocal();
    return defaultDateTimeFormat.format(local);
  }

  /// Formats UTC or local DateTime into date only: '08 Oct 2026'
  static String formatDate(DateTime? dateTime, {String? placeholder}) {
    if (dateTime == null) return placeholder ?? '';
    final local = dateTime.toLocal();
    return defaultDateFormat.format(local);
  }

  /// Formats UTC or local DateTime into time only: '09:10 AM'
  static String formatTime(DateTime? dateTime, {String? placeholder}) {
    if (dateTime == null) return placeholder ?? '';
    final local = dateTime.toLocal();
    return defaultTimeFormat.format(local);
  }

  /// Calculates human-friendly relative time string using local device clock against published timestamp
  static String calculateTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Just now';
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inSeconds < 45) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m${m == 1 ? 'm' : 'm'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h${h == 1 ? 'h' : 'h'} ago';
    }
    if (diff.inDays == 1) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks${weeks == 1 ? 'w' : 'w'} ago';
    }
    return formatDate(local);
  }
}
