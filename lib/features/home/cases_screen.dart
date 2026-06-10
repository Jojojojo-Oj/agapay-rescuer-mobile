import 'package:agapay_rescuers/widget/confirm_acknowledgement_card.dart';
import 'package:agapay_rescuers/widget/sos_report_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agapay_rescuers/widget/incident_report.dart';
import 'package:agapay_rescuers/core/utils/emergency_availability_matcher.dart';

enum CaseFilter {
  all,
  accepted,
  pending,
}

class CasesScreen extends StatefulWidget {
  const CasesScreen({
    super.key,
    required this.userData,
  });

  final Map<String, dynamic> userData;

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  CaseFilter _selectedFilter = CaseFilter.all;
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        
        title: Text(
          'SHOWING ACTIVE INCIDENTS',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.red[400]
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
         
          Expanded(
            child: _CasesList(
              selectedFilter: _selectedFilter,
              searchQuery: _searchQuery,
              emergencyAvailability: resolveEmergencyAvailabilityFromUserData(
                widget.userData,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
              decoration: InputDecoration(
                hintText: "Search incident type",
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
            onTap: () => _openFilterSheet(context),
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

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
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
                  _FilterOption(
                    title: "ALL",
                    selected: _selectedFilter == CaseFilter.all,
                    onTap: () {
                      setState(() => _selectedFilter = CaseFilter.all);
                      Navigator.pop(context);
                    },
                  ),
                  _FilterOption(
                    title: "ACCEPTED",
                    selected: _selectedFilter == CaseFilter.accepted,
                    onTap: () {
                      setState(() => _selectedFilter = CaseFilter.accepted);
                      Navigator.pop(context);
                    },
                  ),
                  _FilterOption(
                    title: "PENDING",
                    selected: _selectedFilter == CaseFilter.pending,
                    onTap: () {
                      setState(() => _selectedFilter = CaseFilter.pending);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CasesList extends StatelessWidget {
  final CaseFilter selectedFilter;
  final String searchQuery;
  final dynamic emergencyAvailability;

  const _CasesList({
    required this.selectedFilter,
    this.searchQuery = "",
    this.emergencyAvailability,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sos_reports')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userId = FirebaseAuth.instance.currentUser?.uid;
        var reports = snapshot.data!.docs
            .where((doc) => doc['status'] == 'active')
            .where((doc) {
              final disasterType = (doc['disasterType'] ?? '').toString();
              return canRescuerHandleIncident(
                emergencyAvailability: emergencyAvailability,
                disasterType: disasterType,
              );
            })
            .toList();

        // Apply search
        if (searchQuery.isNotEmpty) {
          reports = reports.where((doc) {
            final text = ((doc['disasterType'] ?? '') +
                    (doc['location'] ?? '') +
                    (doc['details'] ?? ''))
                .toLowerCase();
            return text.contains(searchQuery);
          }).toList();
        }

        // Apply filter
        if (selectedFilter == CaseFilter.accepted) {
          reports = reports
              .where((doc) {
                final rescuers = doc['rescuers'] as List<dynamic>? ?? [];
                return rescuers.contains(userId);
              })
              .toList();
        } else if (selectedFilter == CaseFilter.pending) {
          reports = reports
              .where((doc) {
                final rescuers = doc['rescuers'] as List<dynamic>? ?? [];
                return !rescuers.contains(userId);
              })
              .toList();
        }

        if (reports.isEmpty) {
          return Center(
            child: Text(
              'No active SOS reports found.',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final data = report.data() as Map<String, dynamic>;

            return SOSReportCard(
              disasterType: data['disasterType'] ?? 'Unknown',
              location: data['location'] ?? 'Unknown location',
              details: data['details'] ?? 'No details provided.',
              imagePath: data['imagePath'] ?? '',
              time: data['time'] ?? '',
              status: data['status'] ?? 'pending',
              onTap: () {
                final userId = FirebaseAuth.instance.currentUser?.uid;
                final acceptedBy = data['acceptedBy'];
                final alreadyAcceptedByCurrentUser =
                    userId != null && acceptedBy == userId;

                void goToIncidentReport() {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IncidentReportScreen(
                        groupChatId: report.id,
                        reportData: data,
                      ),
                    ),
                  );
                }

                if (alreadyAcceptedByCurrentUser) {
                  goToIncidentReport();
                  return;
                }

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => ConfirmAcknowledgementCard(
                    incidentId: report.id,
                    address: (data['location'] ?? '').toString(),
                    disasterType: data['disasterType'] ?? 'Fire',
                    onConfirm: () {
                      Navigator.of(dialogContext).pop();
                      if (userId != null) {
                        FirebaseFirestore.instance
                            .collection('sos_reports')
                            .doc(report.id)
                            .set(
                          {
                            'acceptedBy': userId,
                            'acceptedAt': FieldValue.serverTimestamp(),
                            'rescuers': FieldValue.arrayUnion([userId]),
                          },
                          SetOptions(merge: true),
                        );
                      }
                      goToIncidentReport();
                    },
                    onCancel: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

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
      trailing:
          selected ? const Icon(Icons.check_circle, color: Colors.red) : null,
    );
  }
}