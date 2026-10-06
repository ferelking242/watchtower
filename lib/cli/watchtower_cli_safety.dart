bool _isSensitiveKey(String key) => RegExp(
  r'(password|passwd|secret|token|api[_-]?key|access[_-]?key|authorization|auth(?:entication)?|cookie|session|credential)',
  caseSensitive: false,
).hasMatch(key);

Object? redactCliOutput(Object? value, {bool sensitiveContext = false}) {
  if (value is Map) {
    final settingName = value['key'] ?? value['name'];
    final isSensitiveSetting =
        sensitiveContext ||
        (settingName is String && _isSensitiveKey(settingName));
    const preferenceMetadata = {
      'key',
      'name',
      'title',
      'label',
      'type',
      'type_name',
      'summary',
      'description',
    };
    return value.map((key, entryValue) {
      final name = '$key';
      final nestedValue = entryValue is Map || entryValue is Iterable;
      final redactSettingValue =
          isSensitiveSetting &&
          !preferenceMetadata.contains(name) &&
          !nestedValue;
      return MapEntry(
        name,
        _isSensitiveKey(name) || redactSettingValue
            ? '[REDACTED]'
            : redactCliOutput(entryValue, sensitiveContext: isSensitiveSetting),
      );
    });
  }
  if (value is Iterable) {
    return value
        .map(
          (entry) => redactCliOutput(entry, sensitiveContext: sensitiveContext),
        )
        .toList();
  }
  if (value is String) return sanitizeCliText(value);
  return value;
}

String sanitizeCliText(String value) {
  final withoutUserInfo = value.replaceAllMapped(
    RegExp(r'(https?://[^:/@\s]+:)[^@\s/]+@', caseSensitive: false),
    (match) => '${match.group(1)}[REDACTED]@',
  );
  final withoutQuerySecrets = withoutUserInfo.replaceAllMapped(
    RegExp(
      r'([?&](?:(?:x-amz-)?(?:access[_-]?key|security[_-]?token|credential|signature)|client[_-]?secret|oauth[_-]?token|id[_-]?token|access[_-]?token|refresh[_-]?token|token|api[_-]?key|key|signature|sig|authorization|auth|cookie|session|password|passwd|secret)=)[^&#\s]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}[REDACTED]',
  );
  final withoutHeaderValues = withoutQuerySecrets.replaceAllMapped(
    RegExp(
      r'((?:authorization|proxy-authorization|cookie|set-cookie)\s*[:=]\s*)[^;\r\n]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}[REDACTED]',
  );
  return withoutHeaderValues.replaceAllMapped(
    RegExp(
      r'((?:password|passwd|secret|access[_-]?token|refresh[_-]?token|token|api[_-]?key|credential)\s*[:=]\s*)(?:"[^"]*"|[^\s,;}\]]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}[REDACTED]',
  );
}
