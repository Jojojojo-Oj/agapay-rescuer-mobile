import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class CapturedProofScreen extends StatefulWidget {
  const CapturedProofScreen({
    super.key,
    required this.reportId,
    required this.disasterType,
    required this.location,
    required this.time,
    required this.details,
  });

  final String reportId;
  final String disasterType;
  final String location;
  final String time;
  final String details;

  @override
  State<CapturedProofScreen> createState() => _CapturedProofScreenState();
}

class _CapturedProofScreenState extends State<CapturedProofScreen> {
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _detailsController;
  Uint8List? _capturedImageBytes;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _detailsController = TextEditingController(text: widget.details);
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _captureProofImage() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _capturedImageBytes = bytes;
    });
  }

  Future<void> _confirmResolve() async {
    if (_capturedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture proof photo first.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final imageUrl = await _uploadProofImage(_capturedImageBytes!);
      final reportRef = FirebaseFirestore.instance
          .collection('sos_reports')
          .doc(widget.reportId);

      await reportRef
          .set(
            {
              'status': 'resolved',
              'resolvedAt': FieldValue.serverTimestamp(),
              'resolvedProofImage': imageUrl,
              'resolvedDetails': _detailsController.text.trim(),
            },
            SetOptions(merge: true),
          );

      await reportRef.collection('resolution_logs').add({
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedAtIso': DateTime.now().toIso8601String(),
        'proofImageUrl': imageUrl,
        'additionalDetails': _detailsController.text.trim(),
      });

      if (!mounted) return;
      _showResolvedSuccessDialog();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark as resolved. Please try again.'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<String> _uploadProofImage(Uint8List imageBytes) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance
        .ref('sos_reports/${widget.reportId}/resolution_proofs/$id.jpg');

    await ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return ref.getDownloadURL();
  }

  void _showResolvedSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    color: Color(0xFF32CD32),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 62,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Case Resolved!',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2F2F35),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The Case has been successfully\nresolved.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 170,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003A5D),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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

  Future<String> _resolveAddress(String rawLocation) async {
    final coords = rawLocation.split(',');
    if (coords.length != 2) return rawLocation;

    final lat = double.tryParse(coords[0].trim());
    final lng = double.tryParse(coords[1].trim());
    if (lat == null || lng == null) return rawLocation;

    try {
      final placemarks = await geo.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return rawLocation;

      final place = placemarks.first;
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.country,
      ]
          .where((part) => part != null && part.trim().isNotEmpty)
          .map((part) => part!.trim())
          .toList();

      if (parts.isEmpty) return rawLocation;
      return parts.join(', ');
    } catch (_) {
      return rawLocation;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2ECC40),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          "Confirm Case",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EDF2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// IMAGE SECTION
                      Stack(
                        children: [
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFBDBDBD),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _capturedImageBytes == null
                                ? GestureDetector(
                                    onTap: _captureProofImage,
                                    child: const _ImagePlaceholder(),
                                  )
                                : Image.memory(
                                    _capturedImageBytes!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: ElevatedButton(
                              onPressed: _captureProofImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                elevation: 3,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                "Retake",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      /// DISASTER TYPE
                      Row(
                        children: [
                          Text(
                            "Disaster Type:",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.local_fire_department,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.disasterType,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      /// LOCATION
                      FutureBuilder<String>(
                        future: _resolveAddress(widget.location),
                        builder: (context, snapshot) {
                          final address = snapshot.data ?? widget.location;
                          return Text(
                            "Location: $address",
                            style: GoogleFonts.poppins(fontSize: 15,fontWeight: FontWeight.bold),
                          );
                        },
                      ),

                      const SizedBox(height: 6),

                      /// TIME
                      Text(
                        "Time: ${widget.time}",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold
                        
                        ),
                      ),

                      const SizedBox(height: 18),

                      /// DETAILS LABEL
                      Text(
                        "Additional Details (optional):",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 8),

                      /// DETAILS BOX
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD0D0D0)),
                        ),
                        child: TextField(
                          controller: _detailsController,
                          minLines: 4,
                          maxLines: 7,
                          decoration: InputDecoration(
                            hintText: "Describe your situation or if someone is injured..",
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF9E9E9E),
                            ),
                            border: InputBorder.none,
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _confirmResolve,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC40),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(58),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  "Confirm Resolve",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 60,
            color: Colors.white70,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to capture proof',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}