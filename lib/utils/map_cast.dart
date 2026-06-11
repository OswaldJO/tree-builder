Map<String, dynamic> deepCastMap(Map<dynamic, dynamic> map) {
  return map.map(
    (key, value) => MapEntry(key.toString(), _deepCastValue(value)),
  );
}

dynamic _deepCastValue(dynamic value) {
  if (value is Map) {
    return deepCastMap(Map<dynamic, dynamic>.from(value));
  }
  if (value is List) {
    return value.map(_deepCastValue).toList();
  }
  return value;
}
