import 'package:agapay_rescuers/widget/sos_report_card.dart';
import 'package:agapay_rescuers/core/utils/emergency_availability_matcher.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RescuerHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool embedded;

  const RescuerHomeScreen({
    super.key,
    required this.userData,
    this.embedded = false,
  });

  @override
  State<RescuerHomeScreen> createState() => _RescuerHomeScreenState();
}

class _RescuerHomeScreenState extends State<RescuerHomeScreen> {
  String searchQuery = "";

  /// filters
  String selectedStatus = "all"; // all | active | resolved
  String selectedDisaster =
      "all"; // all | Fire | Earthquake | Typhoon | Medical Assistance

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          _SearchAndFilterBar(
            onSearchChanged: (value) {
              setState(() => searchQuery = value.toLowerCase());
            },
            onFilterPressed: () => _openFilterSheet(context),
          ),
          Expanded(
            child: _ActiveReportsListWrapper(
              searchQuery: searchQuery,
              selectedStatus: selectedStatus,
              selectedDisaster: selectedDisaster,
              emergencyAvailability: resolveEmergencyAvailabilityFromUserData(
                widget.userData,
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Active SOS Reports",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color.fromRGBO(208, 42, 39, 1),
      ),
      body: content,
    );
  }

  /* ================= FILTER BOTTOM SHEET ================= */

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        String expandedSection = ""; // local only

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Filter",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  /* ========= BY STATUS ========= */
                  ListTile(
                    title: Text(
                      "By Status",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    trailing: Icon(
                      expandedSection == "status"
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    onTap: () {
                      setModalState(() {
                        expandedSection = expandedSection == "status"
                            ? ""
                            : "status";
                      });
                    },
                  ),

                  if (expandedSection == "status") ...[
                    _FilterOption(
                      title: "ACTIVE",
                      selected: selectedStatus == "active",
                      onTap: () {
                        setState(() {
                          selectedStatus = selectedStatus == "active"
                              ? "all"
                              : "active";
                          selectedDisaster = "all";
                        });
                        Navigator.pop(context);
                      },
                    ),
                    _FilterOption(
                      title: "RESOLVED",
                      selected: selectedStatus == "resolved",
                      onTap: () {
                        setState(() {
                          selectedStatus = selectedStatus == "resolved"
                              ? "all"
                              : "resolved";
                          selectedDisaster = "all";
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],

                  const SizedBox(height: 8),

                  /* ========= BY DISASTER ========= */
                  ListTile(
                    title: Text(
                      "By Disaster",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    trailing: Icon(
                      expandedSection == "disaster"
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    onTap: () {
                      setModalState(() {
                        expandedSection = expandedSection == "disaster"
                            ? ""
                            : "disaster";
                      });
                    },
                  ),

                  if (expandedSection == "disaster") ...[
                    _FilterOption(
                      title: "FIRE",
                      selected: selectedDisaster == "Fire",
                      onTap: () {
                        setState(() {
                          selectedDisaster = selectedDisaster == "Fire"
                              ? "all"
                              : "Fire";
                          selectedStatus = "all";
                        });
                        Navigator.pop(context);
                      },
                    ),
                    _FilterOption(
                      title: "EARTHQUAKE",
                      selected: selectedDisaster == "Earthquake",
                      onTap: () {
                        setState(() {
                          selectedDisaster = selectedDisaster == "Earthquake"
                              ? "all"
                              : "Earthquake";
                          selectedStatus = "all";
                        });
                        Navigator.pop(context);
                      },
                    ),
                    _FilterOption(
                      title: "TYPHOON",
                      selected: selectedDisaster == "Typhoon",
                      onTap: () {
                        setState(() {
                          selectedDisaster = selectedDisaster == "Typhoon"
                              ? "all"
                              : "Typhoon";
                          selectedStatus = "all";
                        });
                        Navigator.pop(context);
                      },
                    ),
                    _FilterOption(
                      title: "MEDICAL ASSISTANCE",
                      selected: selectedDisaster == "Medical Assistance",
                      onTap: () {
                        setState(() {
                          selectedDisaster =
                              selectedDisaster == "Medical Assistance"
                              ? "all"
                              : "Medical Assistance";
                          selectedStatus = "all";
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/* ================= SEARCH BAR ================= */

class _SearchAndFilterBar extends StatelessWidget {
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterPressed;

  const _SearchAndFilterBar({
    required this.onSearchChanged,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: "Search",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onFilterPressed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

/* ================= ACTIVE REPORTS LIST ================= */

class _ActiveReportsListWrapper extends StatelessWidget {
  final String searchQuery;
  final String selectedStatus;
  final String selectedDisaster;
  final dynamic emergencyAvailability;

  const _ActiveReportsListWrapper({
    required this.searchQuery,
    required this.selectedStatus,
    required this.selectedDisaster,
    this.emergencyAvailability,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sos_reports').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "No internet connection",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var reports = snapshot.data!.docs;

        // Show only incidents that match this rescuer's emergency availability.
        reports = reports.where((doc) {
          final disasterType = (doc['disasterType'] ?? '').toString();
          return canRescuerHandleIncident(
            emergencyAvailability: emergencyAvailability,
            disasterType: disasterType,
          );
        }).toList();

        // 🔎 SEARCH
        if (searchQuery.isNotEmpty) {
          reports = reports.where((doc) {
            final text =
                ((doc['disasterType'] ?? '') +
                        (doc['location'] ?? '') +
                        (doc['details'] ?? ''))
                    .toLowerCase();
            return text.contains(searchQuery);
          }).toList();
        }

        // 🚦 STATUS FILTER (only show active/resolved even when "all")
        const allowedStatuses = {'active', 'resolved'};
        reports = reports.where((doc) {
          final status = (doc['status'] ?? '').toString().trim().toLowerCase();
          if (selectedStatus == 'all') {
            return allowedStatuses.contains(status);
          }
          return status == selectedStatus;
        }).toList();

        // 🔥 DISASTER FILTER
        if (selectedDisaster != "all") {
          reports = reports
              .where((doc) => doc['disasterType'] == selectedDisaster)
              .toList();
        }

        if (reports.isEmpty) {
          return Center(
            child: Text(
              "No SOS reports found.",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];

            return SOSReportCard(
              disasterType: report['disasterType'] ?? 'Unknown',
              location: report['location'] ?? 'Unknown location',
              details: report['details'] ?? 'No details provided.',
              imagePath: report['imagePath'] ?? '',
              time: report['time'] ?? '',
              status: report['status'] ?? 'pending',
              onTap: null,
            );
          },
        );
      },
    );
  }
}

/* ================= FILTER OPTION ================= */

class _FilterOption extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _FilterOption({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(title, style: GoogleFonts.poppins()),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Colors.red)
          : null,
    );
  }
}
