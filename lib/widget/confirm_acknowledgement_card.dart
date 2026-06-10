import 'package:flutter/material.dart';

import 'package:agapay_rescuers/widget/incident_report/location_resolver.dart';

class ConfirmAcknowledgementCard extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String incidentId;
  final String address;
  final String disasterType;

  const ConfirmAcknowledgementCard({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    required this.incidentId,
    required this.address,
    this.disasterType = 'Fire',
  });

  @override
  Widget build(BuildContext context) {
    final normalizedId = incidentId.trim();
    final withoutInc = normalizedId.replaceFirst(RegExp(r'^INC[\s\-]*', caseSensitive: false), '').trim();
    final displayId = withoutInc.isNotEmpty ? withoutInc : (normalizedId.isEmpty ? 'Unknown ID' : normalizedId);
    final resolver = const LocationResolver();

    // Determine color based on disaster type
    final type = disasterType.toLowerCase();
    final Color bannerColor;
    if (type.contains('earthquake')) {
      bannerColor = const Color.fromARGB(255, 248, 167, 16);
    } else if (type.contains('landslide')) {
      bannerColor = Colors.brown;
    } else if (type.contains('tsunami')) {
      bannerColor = Colors.cyan;
    } else if (type.contains('police')) {
      bannerColor = Colors.indigo;
    } else if (type.contains('volcano') || type.contains('volcan')) {
      bannerColor = Colors.deepOrange;
    } else if (type.contains('medical')) {
      bannerColor = Colors.green;
    } else if (type.contains('typhoon')) {
      bannerColor = Colors.blue;
    } else {
      bannerColor = const Color(0xFFE30613);
    }
    final bool darkText = bannerColor.computeLuminance() > 0.6;

    return Center(
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 35,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 36, height: 36),
                  const SizedBox(width: 12),
                  Expanded
                    (child:  const Text(
                        'Confirm Acknowledgement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bannerColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    disasterType.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'Reported',
                    style: TextStyle(
                      color: darkText ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Case ID: $displayId',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<String>(
                    future: resolver.resolve(address),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Loading address...',
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        );
                      }
                      
                      final resolved = snapshot.data ?? address.trim();
                      final display = resolved.isEmpty ? 'Location unavailable' : resolved;

                      return Text(
                        display,
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.black54,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "You're accepting this assignment.\n\n"
                    "You may review full details anytime\n"
                    "in the Cases section.",
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A3D62),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      onPressed: onConfirm,
                      child: const Text(
                        'Confirm and Start',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFFE30613),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: onCancel,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFFE30613),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
