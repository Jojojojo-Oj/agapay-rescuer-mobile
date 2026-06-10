import 'package:agapay_rescuers/features/home/groupchat_screen.dart';
import 'package:agapay_rescuers/features/home/captured_proof_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'incident_report/action_buttons.dart';
import 'incident_report/incident_details_card.dart';
import 'incident_report/location_resolver.dart';
import 'incident_report/track_location.dart';
import 'incident_report/victim_info_card.dart';
import 'incident_report/victim_repository.dart';

class IncidentReportScreen extends StatelessWidget {
  const IncidentReportScreen({
    super.key,
    required this.groupChatId,
    required this.reportData,
    this.locationResolver = const LocationResolver(),
    this.victimRepository = const VictimRepository(),
  });

  final String groupChatId;
  final Map<String, dynamic> reportData;
  final LocationResolver locationResolver;
  final VictimRepository victimRepository;

  @override
  Widget build(BuildContext context) {
    final String disasterType =
      (reportData['disasterType'] ?? 'Incident').toString();
    final String status = (reportData['status'] ?? 'Assigned').toString();
    final String formattedStatus = status.isEmpty
        ? 'Assigned'
        : '${status[0].toUpperCase()}${status.substring(1)}';
    final String time = (reportData['time'] ?? 'N/A').toString();
    final String location = (reportData['location'] ?? 'Unknown location')
        .toString();
    final String imagePath = (reportData['imagePath'] ?? '').toString();
    final String senderId = (reportData['senderID'] ?? reportData['senderId'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey[50],
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(), 
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        centerTitle: true,
        title: Text(
          "Incident Report",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Victim Information",
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            VictimInfoCard(
              senderId: senderId,
              formattedStatus: formattedStatus,
              repository: victimRepository,
            ),

            const SizedBox(height: 16),

            IncidentDetailsCard(
              disasterType: disasterType,
              groupChatId: groupChatId,
              formattedStatus: formattedStatus,
              time: time,
              location: location,
              imagePath: imagePath,
              locationResolver: locationResolver,
              onImageTap: () => _showImageOverlay(context, imagePath),
            ),

            const SizedBox(height: 28),

            IncidentActionButtons(
              onMessage: () => _openGroupChat(context),
              onTrack: () => _openTrackLocation(context, location, disasterType),
              onResolve: () => _showResolveDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _openGroupChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RescuerGroupChatScreen(
          groupChatId: groupChatId,
        ),
      ),
    );
  }

  void _showImageOverlay(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black.withOpacity(0.8),
          alignment: Alignment.center,
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markResolved(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('sos_reports')
          .doc(groupChatId)
          .set(
            {
              'status': 'resolved',
              'resolvedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as resolved.')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark as resolved. Please try again.'),
        ),
      );
    }
  }

  void _openTrackLocation(BuildContext context, String rawLocation, String disasterType) {
    final parts = rawLocation.split(',');
    if (parts.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid incident location.')),
      );
      return;
    }

    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid incident coordinates.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackLocationScreen(
          destLat: lat,
          destLng: lng,
          destinationLabel: disasterType,
          senderId: (reportData['senderID'] ?? reportData['senderId'] ?? '').toString(),
          groupChatId: groupChatId,
          // Arrival should not mark resolved; handled in tracker via chat only
        ),
      ),
    );
  }

  void _showResolveDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirm Resolution?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please ensure the rescue operation is complete.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await _resolveCase(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34C759),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      'CONFIRM',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black87),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showResolvedSuccessDialog(BuildContext context, {bool redirectToCases = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Case Resolved!',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The case has been successfully resolved.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      if (redirectToCases) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B2C3D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _resolveCase(BuildContext context) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CapturedProofScreen(
          reportId: groupChatId,
          disasterType: (reportData['disasterType'] ?? 'Unknown').toString(),
          location: (reportData['location'] ?? 'Unknown location').toString(),
          time: (reportData['time'] ?? '').toString(),
          details: (reportData['details'] ?? '').toString(),
        ),
      ),
    );
  }
}