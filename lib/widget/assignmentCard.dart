import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agapay_rescuers/widget/incident_report/location_resolver.dart';

class AssignmentCard extends StatefulWidget {
  final String type;
  final String statusLabel;
  final String incidentCode;
  final String address;
  final String summary;
  final int countdownSeconds;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onDecline;

  const AssignmentCard({
    super.key,
    this.type = 'FIRE',
    this.statusLabel = 'Reported',
    this.incidentCode = 'INC-000000',
    this.address = 'Address unavailable',
    this.summary = 'Please review and respond.',
    this.countdownSeconds = 176,
    this.onAcknowledge,
    this.onDecline,
  });

  @override
  State<AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<AssignmentCard> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds == 0) {
        timer.cancel();
        if (!mounted) return;
        if (widget.onDecline != null) {
          widget.onDecline!.call();
        } else {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  Future<void> _showUnableToRespondNotice() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            width: 360,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 35,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 36,
                        height: 36,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Unable to Respond',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE30613),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NOTICE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'Unable to Respond',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Text(
                    'Proceeding will move this case to the Case Page. This action may be canceled if you reconsider.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A3D62),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (widget.onDecline != null) {
                              widget.onDecline!.call();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFE30613),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFFE30613),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAcknowledgementConfirmation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            width: 360,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 35,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 36,
                        height: 36,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Acknowledge',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE30613),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NOTICE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'Acknowledged',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Text(
                    'By acknowledging this assignment, you confirm acceptance of the case and will be directed to the Case Page to begin.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A3D62),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (widget.onAcknowledge != null) {
                              widget.onAcknowledge!.call();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFE30613),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFFE30613),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type.toLowerCase();
    final Color bannerColor;
    if (type.contains('earthquake')) {
      bannerColor = const Color.fromARGB(255, 248, 167, 16);
    } else if (type.contains('landslide')) {
      bannerColor = Colors.brown;
    } else if (type.contains('tsunami')) {
      bannerColor = Colors.cyan;
    } else if (type.contains('police')) {
      bannerColor = Colors.indigo;
    } else if (type.contains('volcano') || type.contains('volcan')) {
      bannerColor = Colors.deepOrange;
    } else if (type.contains('medical')) {
      bannerColor = Colors.green;
    } else if (type.contains('typhoon')) {
      bannerColor = Colors.blue;
    } else {
      bannerColor = const Color(0xFFE30613);
    }
    final bool darkText = bannerColor.computeLuminance() > 0.6;
    final resolver = const LocationResolver();

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 24, 10, 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -20,
              left: 14,
              right: 14,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.58),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -10,
              left: 8,
              right: 8,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.09),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 360,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 35,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔹 HEADER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 36,
                          height: 36,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'New Assignment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// 🔴 STATUS BAR
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bannerColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.type.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          widget.statusLabel,
                          style: TextStyle(
                            color: darkText ? Colors.black87 : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// 🔹 CONTENT
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Case ID: ${widget.incidentCode}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FutureBuilder<String>(
                          future: resolver.resolve(widget.address),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Loading address...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              );
                            }

                            final resolved =
                                snapshot.data ?? widget.address.trim();
                            final display = resolved.isEmpty
                                ? 'Location unavailable'
                                : resolved;

                            return Text(
                              display,
                              style: const TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.black54,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 18),

                        /// ⏱ LIVE TIMER
                        Text(
                          'Acknowledge this\nassignment within $_formattedTime',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: Colors.red,
                          ),
                        ),

                        const SizedBox(height: 10),
                        const Text(
                          'Responding now helps reduce delays, improves emergency coordination, and ensures faster, more effective assistance for those in immediate danger.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.black54,
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                        Text(
                          widget.summary,
                          style: const TextStyle(
                            fontSize: 14,
                            height: .5,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// 🔹 BUTTONS
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A3D62),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                            ),
                            onPressed: _showAcknowledgementConfirmation,
                            child: const Text(
                              'Acknowledge Assignment',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFE30613),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _showUnableToRespondNotice,
                            child: const Text(
                              'Unable to Respond',
                              style: TextStyle(
                                color: Color(0xFFE30613),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
