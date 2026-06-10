import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IncidentInfoRow extends StatelessWidget {
  const IncidentInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.link = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool link;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Icon(icon, color: const Color.fromRGBO(223, 9, 26, 1), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: link ? Colors.blue : Colors.grey,
                  decoration: link ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: link && onTap != null ? InkWell(onTap: onTap, child: content) : content,
    );
  }
}
