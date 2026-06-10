import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';

class SOSReportCard extends StatelessWidget {
  static final Map<String, Future<String>> _addressCache = {};

  final String disasterType;
  final String location;
  final String details;
  final String imagePath;
  final String time;
  final String status;
  final VoidCallback? onTap;

  const SOSReportCard({
    super.key,
    required this.disasterType,
    required this.location,
    required this.details,
    required this.imagePath,
    required this.time,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    /// 🎨 HEADER COLOR BASED ON DISASTER TYPE
    Color headerColor;

    switch (disasterType.toLowerCase()) {
      case 'fire':
        headerColor = const Color(0xFFE30613);
        break;
      case 'landslide':
        headerColor = Colors.brown.shade700;
        break;
      case 'tsunami':
        headerColor = Colors.cyan.shade700;
        break;
      case 'police':
      case 'police incident':
        headerColor = Colors.indigo.shade700;
        break;
      case 'volcano':
      case 'volcan':
        headerColor = Colors.deepOrange.shade700;
        break;
      case 'typhoon':
        headerColor = Colors.blue.shade700;
        break;
      case 'earthquake':
        headerColor = Colors.orange.shade600;
        break;
      case 'medical assistance':
      case 'medical':
        headerColor = Colors.green.shade700;
        break;
      default:
        headerColor = Colors.grey.shade700;
    }

    final card = Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  disasterType.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String>(
                  future: _resolveLocationText(location),
                  builder: (context, snapshot) {
                    final resolved = snapshot.data;
                    final waiting =
                        snapshot.connectionState == ConnectionState.waiting;
                    final displayLocation =
                        resolved ??
                        (waiting ? 'Resolving address...' : location);

                    return Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            displayLocation,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 8),

                Text(
                  details,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),

                const SizedBox(height: 10),

                if (imagePath.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imagePath,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 180,
                          width: double.infinity,
                          alignment: Alignment.center,
                          color: Colors.grey.shade200,
                          child: Text(
                            'No internet connection',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    time,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }

  Future<String> _resolveLocationText(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return Future.value('Location unavailable');

    final coords = _parseLatLng(normalized);
    if (coords == null) return Future.value(normalized);

    final cached = _addressCache[normalized];
    if (cached != null) return cached;

    final future = _reverseGeocode(coords)
        .then(
          (resolved) =>
              resolved != null && resolved.isNotEmpty ? resolved : normalized,
        )
        .catchError((_) => normalized);

    _addressCache[normalized] = future;
    return future;
  }

  _LatLng? _parseLatLng(String raw) {
    final parts = raw.split(',');
    if (parts.length != 2) return null;

    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;

    return _LatLng(lat, lng);
  }

  Future<String?> _reverseGeocode(_LatLng coords) async {
    final placemarks = await geo.placemarkFromCoordinates(
      coords.lat,
      coords.lng,
    );
    final place = placemarks.isNotEmpty ? placemarks.first : null;
    if (place == null) return null;

    return _formatPlacemark(place);
  }

  String? _formatPlacemark(geo.Placemark placemark) {
    final parts =
        [
              placemark.street,
              placemark.subLocality,
              placemark.locality,
              placemark.administrativeArea,
              placemark.country,
            ]
            .where((part) => part != null && part.isNotEmpty)
            .map((part) => part!)
            .toList();

    if (parts.isEmpty) return null;

    return parts.join(', ');
  }
}

class _LatLng {
  final double lat;
  final double lng;

  const _LatLng(this.lat, this.lng);
}
