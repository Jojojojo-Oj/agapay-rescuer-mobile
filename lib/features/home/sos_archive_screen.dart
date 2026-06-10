import 'package:flutter/material.dart';

import '../../core/hive/sos_hive_service.dart';

class SosArchiveScreen extends StatefulWidget {
  const SosArchiveScreen({super.key});

  @override
  State<SosArchiveScreen> createState() => _SosArchiveScreenState();
}

class _SosArchiveScreenState extends State<SosArchiveScreen> {
  late List<Map<String, dynamic>> _records;

  @override
  void initState() {
    super.initState();
    _records = SosHiveService.getResolvedRecords();
  }

  String _formatTs(int? ms) {
    if (ms == null) return 'Unknown';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)} '
        '${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}'
        '.${dt.millisecond.toString().padLeft(3, '0')}';
  }

  Widget _buildCard(Map<String, dynamic> record) {
    final lat = (record['latitude'] as num?)?.toDouble();
    final lon = (record['longitude'] as num?)?.toDouble();
    final battery = record['battery'] as int?;
    final senderHash = (record['senderHash'] as String?) ?? '';
    final receivedAt = _formatTs(record['receivedAt'] as int?);
    final resolvedAt = _formatTs(record['resolvedAt'] as int?);
    final deviceId = (record['deviceId'] as String?) ?? 'Cloud';

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
          // ── Red header ──────────────────────────────────────
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
                    'Received: $receivedAt',
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
          // ── Body ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device: $deviceId',
                  style: const TextStyle(
                    color: Color(0xFF2F2F2F),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Latitude: ${lat?.toStringAsFixed(6) ?? 'Unknown'}'),
                const SizedBox(height: 2),
                Text('Longitude: ${lon?.toStringAsFixed(6) ?? 'Unknown'}'),
                const SizedBox(height: 2),
                Text('Battery: ${battery == null ? 'Unknown' : '$battery%'}'),
                const SizedBox(height: 2),
                Text('Sender Hash: $senderHash'),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E2E2)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Resolved: $resolvedAt',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF555555),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28A745),
                          disabledBackgroundColor: const Color(0xFF28A745),
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'CASE RESOLVED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        title: const Text(
          'Archive',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _records.isEmpty
          ? const Center(
              child: Text(
                'No resolved cases yet.',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              itemCount: _records.length,
              itemBuilder: (context, index) => _buildCard(_records[index]),
            ),
    );
  }
}
