import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'incident_info_row.dart';
import 'location_resolver.dart';

class IncidentDetailsCard extends StatelessWidget {
  const IncidentDetailsCard({
    super.key,
    required this.disasterType,
    required this.groupChatId,
    required this.formattedStatus,
    required this.time,
    required this.location,
    required this.imagePath,
    required this.onImageTap,
    this.locationResolver = const LocationResolver(),
  });

  final String disasterType;
  final String groupChatId;
  final String formattedStatus;
  final String time;
  final String location;
  final String imagePath;
  final VoidCallback onImageTap;
  final LocationResolver locationResolver;

  Color _getHeaderColor(String disasterType) {
    final type = disasterType.toLowerCase();
    if (type.contains('earthquake')) {
      return const Color.fromARGB(255, 248, 167, 16);
    } else if (type.contains('landslide')) {
      return Colors.brown;
    } else if (type.contains('tsunami')) {
      return Colors.cyan;
    } else if (type.contains('police')) {
      return Colors.indigo;
    } else if (type.contains('volcano') || type.contains('volcan')) {
      return Colors.deepOrange;
    } else if (type.contains('medical')) {
      return Colors.green;
    } else if (type.contains('typhoon')) {
      return Colors.blue;
    } else {
      return const Color.fromRGBO(223, 9, 26, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: _getHeaderColor(disasterType),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "${disasterType.toUpperCase()}: $groupChatId",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(255, 234, 167, 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formattedStatus,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          IncidentInfoRow(
            icon: Icons.access_time,
            title: "Time Reported",
            value: time,
          ),
          FutureBuilder<String>(
            future: locationResolver.resolve(location),
            builder: (context, snapshot) {
              final resolved = snapshot.data;
              final waiting = snapshot.connectionState == ConnectionState.waiting;
              final displayLocation = resolved ?? (waiting ? 'Resolving address...' : location);
              return IncidentInfoRow(
                icon: Icons.location_on,
                title: "Location",
                value: displayLocation,
              );
            },
          ),
          IncidentInfoRow(
            icon: Icons.image,
            title: "Photo Proof",
            value: imagePath.isEmpty ? "No image provided" : "View Image",
            link: imagePath.isNotEmpty,
            onTap: imagePath.isEmpty ? null : onImageTap,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
