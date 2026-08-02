import 'package:intl/intl.dart';

String formatCents(
  int? cents, {
  String? fallback,
  String? locale,
  String? currency,
}) {
  if (cents == null) return fallback ?? 'Pay listed in post';
  return NumberFormat.simpleCurrency(
    locale: locale,
    name: currency,
    decimalDigits: 2,
  ).format(cents / 100);
}

String formatDateTime(Object? value, {String? locale}) {
  if (value == null) return 'Not set';
  final parsed = value is DateTime
      ? value
      : DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('MMM d, h:mm a', locale).format(parsed.toLocal());
}

String compactDate(Object? value, {String? locale}) {
  if (value == null) return 'Not set';
  final parsed = value is DateTime
      ? value
      : DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('MMM d', locale).format(parsed.toLocal());
}

String titleCase(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}
