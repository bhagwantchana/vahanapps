int toInt(dynamic value, {int fallback = 0}) {
  if (value == null) {
    return fallback;
  }
  if (value is int) {
    return value;
  }
  if (value is bool) {
    return value ? 1 : 0;
  }
  if (value is num) {
    return value.toInt();
  }
  final raw = value.toString().trim().toLowerCase();
  if (raw.isEmpty) {
    return fallback;
  }
  if (raw == 'on' || raw == 'true' || raw == 'yes' || raw == 'active') {
    return 1;
  }
  if (raw == 'off' || raw == 'false' || raw == 'no' || raw == 'inactive') {
    return 0;
  }
  return int.tryParse(raw) ?? fallback;
}

double toDouble(dynamic value, {double fallback = 0}) {
  if (value == null) {
    return fallback;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? fallback;
}

String toStringValue(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final output = value.toString();
  return output.trim().isEmpty ? fallback : output;
}

String humanizeSnakeCase(dynamic value, {String fallback = '--'}) {
  final raw = toStringValue(value).trim();
  if (raw.isEmpty) {
    return fallback;
  }

  return raw
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .map((item) {
        if (item.length == 1) {
          return item.toUpperCase();
        }
        return '${item[0].toUpperCase()}${item.substring(1).toLowerCase()}';
      })
      .join(' ');
}

bool toBoolFlag(dynamic value, {bool fallback = false}) {
  if (value == null) {
    return fallback;
  }
  return toInt(value, fallback: fallback ? 1 : 0) == 1;
}

DateTime? toDateTime(dynamic value) {
  final rawValue = toStringValue(value);
  if (rawValue.isEmpty) {
    return null;
  }
  return DateTime.tryParse(rawValue);
}
