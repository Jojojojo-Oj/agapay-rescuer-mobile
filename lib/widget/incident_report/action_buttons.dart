import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IncidentActionButtons extends StatelessWidget {
  const IncidentActionButtons({
    super.key,
    required this.onMessage,
    required this.onTrack,
    required this.onResolve,
  });

  final VoidCallback onMessage;
  final VoidCallback onTrack;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: OutlinedButton(
                  onPressed: onMessage,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    "Message",
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: onTrack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2C3D),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    "Track Location",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: onResolve,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              "Mark as Resolved",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
