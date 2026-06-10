import 'package:flutter/material.dart';

class IncidentCard extends StatelessWidget {
  final String type;
  final String status;
  final String title;
  final String location;
  final String description;
  final String reportedTime;
  final Color headerColor;
  final IconData icon;

  const IncidentCard({
    super.key,
    required this.type,
    required this.status,
    required this.title,
    required this.location,
    required this.description,
    required this.reportedTime,
    required this.icon,
    this.headerColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  type.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          /// BODY
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// ICON
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: headerColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: headerColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),

                    /// TITLE + LOCATION
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            location,
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                /// DESCRIPTION
                const Text(
                  'This incident is active/ongoing',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 14),

                /// TIME
                Text(
                  reportedTime,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
