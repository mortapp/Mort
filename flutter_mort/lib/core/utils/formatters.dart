import 'package:intl/intl.dart';

String formatCents(int? cents, {String? fallback}) {
  if (cents == null) return fallback ?? 'Pay listed in post';
  return NumberFormat.simpleCurrency(decimalDigits: 0).format(cents / 100);
}

String formatDateTime(Object? value) {
  if (value == null) return 'Not set';
  final parsed = value is DateTime
      ? value
      : DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('MMM d, h:mm a').format(parsed.toLocal());
}

String compactDate(Object? value) {
  if (value == null) return 'Not set';
  final parsed = value is DateTime
      ? value
      : DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('MMM d').format(parsed.toLocal());
}

String titleCase(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}
