import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/hive/sos_hive_service.dart';
import 'sos_archive_screen.dart';
import 'sos_navigation_screen.dart';

class EmergencyScanScreen extends StatefulWidget {
  const EmergencyScanScreen({super.key});

  @override
  State<EmergencyScanScreen> createState() => _EmergencyScanScreenState();
}

class _EmergencyScanScreenState extends State<EmergencyScanScreen> {
  static const int _manufacturerId = 0x1234;
  static const int _payloadLength = 18;
  static const String _pendingKey = 'pending_sos_payloads';

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isScanning = false;
  String? _statusMessage;

  final List<SosScanRecord> _records = [];
  final Set<String> _seen = <String>{};

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        _flushPendingUploads();
      }
    });
  }

  @override
  void dispose() {
    _stopScan(showToast: false);
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    final permissionsOk = await _ensurePermissions();
    if (!permissionsOk) {
      setState(() {
        _statusMessage = 'Bluetooth or location permission denied.';
      });
      return;
    }

    final bluetoothOk = await _ensureBluetoothOn();
    if (!bluetoothOk) {
      setState(() {
        _statusMessage = 'Bluetooth is off.';
      });
      return;
    }

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen(_handleScanResults);

    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for emergency beacons...';
    });
    _showToast('Scanning for Emergency beacon');

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(minutes: 5));
    } catch (e) {
      setState(() {
        _statusMessage = 'Scan failed: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _stopScan({bool showToast = true}) async {
    await _scanSub?.cancel();
    _scanSub = null;

    if (_isScanning) {
      await FlutterBluePlus.stopScan();
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan stopped.';
      });
      if (showToast) {
        _showToast('Scanning stopped');
      }
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        ),
      );
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<bool> _ensureBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    if (state == BluetoothAdapterState.on) return true;

    await FlutterBluePlus.turnOn();
    final updated = await FlutterBluePlus.adapterState.first;
    return updated == BluetoothAdapterState.on;
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      final manufacturerData = result.advertisementData.manufacturerData;
      for (final entry in manufacturerData.entries) {
        if (entry.key != _manufacturerId) continue;

        final payload = Uint8List.fromList(entry.value);
        if (payload.length != _payloadLength) continue;

        final key = base64Encode(payload);
        if (_seen.contains(key)) continue;

        final parsed = _parsePayload(payload);

        _seen.add(key);
        _records.insert(
          0,
          SosScanRecord(
            payload: payload,
            parsed: parsed,
            rssi: result.rssi,
            receivedAt: DateTime.now(),
            deviceId: result.device.remoteId.str,
          ),
        );

        _uploadIfOnline(payload);

        // Persist locally
        final dedupeKey = '${_toHex(parsed.idHash)}_${parsed.timestampSeconds}';
        SosHiveService.saveRecord(
          dedupeKey: dedupeKey,
          latitude: parsed.latitude,
          longitude: parsed.longitude,
          battery: parsed.battery == 255 ? null : parsed.battery,
          ttl: parsed.ttl,
          senderHash: _toHex(parsed.idHash),
          receivedAt: DateTime.now(),
          rssi: result.rssi,
          deviceId: result.device.remoteId.str,
          payloadHex: _toHex(Uint8List.fromList(entry.value)),
        );

        if (mounted) {
          setState(() {
            _statusMessage = 'Found ${_records.length} SOS beacon(s).';
          });
        }
      }
    }
  }

  SosPayload _parsePayload(Uint8List payload) {
    final data = ByteData.sublistView(payload);

    final battery = data.getUint8(0);
    final latMicros = data.getInt32(1, Endian.little);
    final lonMicros = data.getInt32(5, Endian.little);
    final timestamp = data.getUint32(9, Endian.little);
    final idHash = payload.sublist(13, 17);
    final ttl = data.getUint8(17);

    return SosPayload(
      battery: battery,
      latitude: latMicros / 1000000,
      longitude: lonMicros / 1000000,
      timestampSeconds: timestamp,
      idHash: Uint8List.fromList(idHash),
      ttl: ttl,
    );
  }

  Future<void> _uploadIfOnline(Uint8List payload) async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      await _storePending(payload);
      return;
    }

    try {
      await _uploadToFirestore(payload);
    } catch (_) {
      await _storePending(payload);
    }
  }

  Future<void> _uploadToFirestore(Uint8List payload) async {
    final parsed = _parsePayload(payload);
    final docId = '${_toHex(parsed.idHash)}_${parsed.timestampSeconds}';

    await FirebaseFirestore.instance
        .collection('sos_reports_emergency')
        .doc(docId)
        .set({
          'senderIdHash': _toHex(parsed.idHash),
          'timeServer': FieldValue.serverTimestamp(),
          'latitude': parsed.latitude,
          'longitude': parsed.longitude,
          'batteryLevel': parsed.battery == 255 ? null : parsed.battery,
          'ttl': parsed.ttl,
        }, SetOptions(merge: true));
  }

  Future<void> _storePending(Uint8List payload) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_pendingKey) ?? <String>[];
    final encoded = base64Encode(payload);
    if (existing.contains(encoded)) return;
    await prefs.setStringList(_pendingKey, [...existing, encoded]);
  }

  Future<void> _flushPendingUploads() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? <String>[];
    if (pending.isEmpty) return;

    final remaining = <String>[];
    for (final item in pending) {
      try {
        final payload = base64Decode(item);
        await _uploadToFirestore(Uint8List.fromList(payload));
      } catch (_) {
        remaining.add(item);
      }
    }

    await prefs.setStringList(_pendingKey, remaining);
  }

  String _toHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  String _formatReceivedAt(DateTime? receivedAt) {
    if (receivedAt == null) return 'Unknown';
    final local = receivedAt.toLocal();

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}.'
        '${local.millisecond.toString().padLeft(3, '0')}';
  }

  Widget _buildSosCard(BuildContext context, SosCardData data) {
    final latitudeText = data.latitude == null
        ? 'Unknown'
        : data.latitude!.toStringAsFixed(6);
    final longitudeText = data.longitude == null
        ? 'Unknown'
        : data.longitude!.toStringAsFixed(6);
    final batteryText = data.battery == null ? 'Unknown' : '${data.battery}%';
    final ttlText = data.ttl?.toString() ?? '-';
    final senderHash = data.senderHash ?? 'Unknown';
    final receivedText = _formatReceivedAt(data.receivedAt);
    final deviceText = data.deviceId ?? 'Cloud';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDADADA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFE20D1C),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'SOS BEACON',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    'Received: $receivedText',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device: $deviceText',
                  style: const TextStyle(
                    color: Color(0xFF2F2F2F),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (data.rssi != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'RSSI: ${data.rssi}',
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text('Latitude: $latitudeText'),
                const SizedBox(height: 2),
                Text('Longitude: $longitudeText'),
                const SizedBox(height: 2),
                Text('Battery: $batteryText'),
                const SizedBox(height: 2),
                Text('TTL: $ttlText'),
                const SizedBox(height: 2),
                Text('Sender Hash: $senderHash'),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E2E2)),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: data.latitude == null || data.longitude == null
                          ? null
                          : () => _openNavigation(data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003D5A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF9AA9B1),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'NAVIGATE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                if (data.payloadHex != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Payload: ${data.payloadHex}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNavigation(SosCardData data) async {
    final latitude = data.latitude;
    final longitude = data.longitude;
    if (latitude == null || longitude == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SosNavigationScreen(
          latitude: latitude,
          longitude: longitude,
          senderHash: data.senderHash,
          dedupeKey: data.dedupeKey,
        ),
      ),
    );

    // Rebuild immediately after returning so Hive-resolved cards are filtered
    // out even while the device is offline.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: const Color(0xFFF1F1F1),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(children: [const SizedBox(width: 10)]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isScanning ? _stopScan : _startScan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning
                              ? const Color(0xFFE20D1C)
                              : const Color(0xFF0B5C7A),
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: _isScanning
                                  ? const Color(0xFFB50A16)
                                  : const Color(0xFF094860),
                            ),
                          ),
                        ),
                        child: Text(
                          _isScanning ? 'Stop Scanning' : 'Start Scanning',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCECECE)),
                    ),
                    child: IconButton(
                      tooltip: 'Archive',
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SosArchiveScreen(),
                          ),
                        );
                      },
                      icon: SvgPicture.asset(
                        'assets/icons/archiveIcon.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF666666),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Row(
                  children: [
                    Icon(
                      _isScanning
                          ? Icons.bluetooth_searching
                          : Icons.info_outline,
                      size: 16,
                      color: const Color(0xFF616161),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('sos_reports_emergency')
                    .orderBy('timeServer', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final cloudDocs = snapshot.data?.docs ?? [];
                  final cloudItems = cloudDocs.map((doc) {
                    final data = doc.data();
                    final battery = data['batteryLevel'];
                    final timestamp = data['timeServer'] as Timestamp?;
                    final senderHash = data['senderIdHash'] as String?;

                    return SosCardData(
                      latitude: (data['latitude'] as num?)?.toDouble(),
                      longitude: (data['longitude'] as num?)?.toDouble(),
                      battery: battery is num ? battery.toInt() : null,
                      ttl: data['ttl'] as int?,
                      senderHash: senderHash,
                      receivedAt: timestamp?.toDate(),
                      dedupeKey: doc.id.isNotEmpty
                          ? doc.id
                          : '${senderHash ?? 'unknown'}_${timestamp?.millisecondsSinceEpoch ?? 0}',
                    );
                  }).toList();

                  final bleItems = _records.map((record) {
                    final parsed = record.parsed;
                    final battery = parsed.battery == 255
                        ? null
                        : parsed.battery;

                    return SosCardData(
                      latitude: parsed.latitude,
                      longitude: parsed.longitude,
                      battery: battery,
                      ttl: parsed.ttl,
                      senderHash: _toHex(parsed.idHash),
                      receivedAt: record.receivedAt,
                      dedupeKey:
                          '${_toHex(parsed.idHash)}_${parsed.timestampSeconds}',
                      rssi: record.rssi,
                      deviceId: record.deviceId,
                      payloadHex: _toHex(record.payload),
                    );
                  }).toList();

                  final deduped = <String, SosCardData>{};
                  for (final item in [...bleItems, ...cloudItems]) {
                    deduped.putIfAbsent(item.dedupeKey, () => item);
                  }

                  // Exclude cases that have already been resolved.
                  final resolvedKeys = SosHiveService.getResolvedRecords()
                      .map((r) => r['dedupeKey'] as String)
                      .toSet();

                  final items = deduped.values
                      .where((item) => !resolvedKeys.contains(item.dedupeKey))
                      .toList();
                  items.sort(
                    (a, b) =>
                        (b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                            .compareTo(
                              a.receivedAt ??
                                  DateTime.fromMillisecondsSinceEpoch(0),
                            ),
                  );

                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'No SOS beacons detected yet.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _buildSosCard(context, items[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SosPayload {
  final int battery;
  final double latitude;
  final double longitude;
  final int timestampSeconds;
  final Uint8List idHash;
  final int ttl;

  const SosPayload({
    required this.battery,
    required this.latitude,
    required this.longitude,
    required this.timestampSeconds,
    required this.idHash,
    required this.ttl,
  });
}

class SosScanRecord {
  final Uint8List payload;
  final SosPayload parsed;
  final int rssi;
  final DateTime receivedAt;
  final String deviceId;

  const SosScanRecord({
    required this.payload,
    required this.parsed,
    required this.rssi,
    required this.receivedAt,
    required this.deviceId,
  });
}

class SosCardData {
  final String dedupeKey;
  final double? latitude;
  final double? longitude;
  final int? battery;
  final int? ttl;
  final String? senderHash;
  final DateTime? receivedAt;
  final int? rssi;
  final String? deviceId;
  final String? payloadHex;

  const SosCardData({
    required this.dedupeKey,
    required this.latitude,
    required this.longitude,
    required this.battery,
    required this.ttl,
    required this.senderHash,
    required this.receivedAt,
    this.rssi,
    this.deviceId,
    this.payloadHex,
  });
}
