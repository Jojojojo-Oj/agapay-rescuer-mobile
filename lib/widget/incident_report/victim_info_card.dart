import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'victim_info.dart';
import 'victim_repository.dart';

class VictimInfoCard extends StatelessWidget {
  const VictimInfoCard({
    super.key,
    required this.senderId,
    required this.formattedStatus,
    this.repository = const VictimRepository(),
  });

  final String senderId;
  final String formattedStatus;
  final VictimRepository repository;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: FutureBuilder<VictimInfo>(
        future: repository.fetchBySenderId(senderId),
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final info = snapshot.data;

          final victimName = info?.name ?? (loading ? 'Loading...' : 'Unknown sender');
          final victimPhone = info?.phone ?? (loading ? 'Loading...' : 'Unknown phone');
          final victimEmail = info?.email ?? (loading ? 'Loading...' : 'No email provided');
          final victimAddress = info?.address ?? (loading ? 'Loading...' : 'No address provided');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "STATUS: ${formattedStatus.toUpperCase()}",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                victimName,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          victimPhone,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          victimEmail,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      victimAddress,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
