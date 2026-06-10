import 'package:hive_flutter/hive_flutter.dart';

class SosHiveService {
  static const String _boxName = 'sos_records';

  static Box get _box => Hive.box(_boxName);

  /// Persists a new SOS record. Skipped if dedupeKey already exists.
  static Future<void> saveRecord({
    required String dedupeKey,
    required double? latitude,
    required double? longitude,
    required int? battery,
    required int? ttl,
    required String? senderHash,
    required DateTime? receivedAt,
    required int? rssi,
    required String? deviceId,
    required String? payloadHex,
  }) async {
    if (_box.containsKey(dedupeKey)) return;
    await _box.put(dedupeKey, {
      'dedupeKey': dedupeKey,
      'latitude': latitude,
      'longitude': longitude,
      'battery': battery,
      'ttl': ttl,
      'senderHash': senderHash,
      'receivedAt': receivedAt?.millisecondsSinceEpoch,
      'rssi': rssi,
      'deviceId': deviceId,
      'payloadHex': payloadHex,
      'isResolved': false,
      'resolvedAt': null,
    });
  }

  /// Marks an existing record as resolved.
  static Future<void> markResolved(String dedupeKey) async {
    final raw = _box.get(dedupeKey);
    final Map<String, dynamic> record = raw != null
        ? Map<String, dynamic>.from(raw as Map)
        : {'dedupeKey': dedupeKey};
    record['isResolved'] = true;
    record['resolvedAt'] = DateTime.now().millisecondsSinceEpoch;
    await _box.put(dedupeKey, record);
  }

  /// Returns all resolved records sorted by resolvedAt descending.
  static List<Map<String, dynamic>> getResolvedRecords() {
    final list = _box.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => e['isResolved'] == true)
        .toList();
    list.sort(
      (a, b) =>
          ((b['resolvedAt'] as int?) ?? 0)
              .compareTo((a['resolvedAt'] as int?) ?? 0),
    );
    return list;
  }
}
