import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VictimFloatingCard extends StatelessWidget {
  const VictimFloatingCard({
    super.key,
    required this.victimName,
    required this.address,
    this.photoUrl,
    required this.onCall,
    required this.onMessage,
    required this.onArrived,
    this.arrivedEnabled = true,
  });

  final String victimName;
  final String address;
  final String? photoUrl;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback onArrived;
  final bool arrivedEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// 🔹 HEADER
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl!.isNotEmpty
                      ? Image.network(
                          photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      victimName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// 🔹 CALL & MESSAGE
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onCall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: Text(
                    'CALL',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onMessage,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'MESSAGE',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// 🔹 ARRIVED BUTTON (WITH SHADOW)
          Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black.withOpacity(0.3),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: arrivedEnabled ? onArrived : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0, // prevent double shadow
                ),
                child: Text(
                  'ARRIVED',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
