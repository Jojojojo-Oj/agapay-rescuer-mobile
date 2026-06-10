import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:agapay_rescuers/core/models/chat_message.dart';
import 'location_resolver.dart';
import 'victim_repository.dart';
import 'package:agapay_rescuers/features/home/groupchat_screen.dart';

import 'victim_floating_card.dart';

class TrackLocationScreen extends StatefulWidget {
  const TrackLocationScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    this.destinationLabel = 'Incident',
    this.victimName,
    this.victimAddress,
    this.onMessage,
    this.onArrived,
    required this.senderId,
    required this.groupChatId,
    this.locationResolver = const LocationResolver(),
    this.victimRepository = const VictimRepository(),
  });

  final double destLat;
  final double destLng;
  final String destinationLabel;
  final String? victimName;
  final String? victimAddress;
  final VoidCallback? onMessage;
  final VoidCallback? onArrived;
  final String senderId;
  final String groupChatId;
  final LocationResolver locationResolver;
  final VictimRepository victimRepository;

  @override
  State<TrackLocationScreen> createState() => _TrackLocationScreenState();
}

class _TrackLocationScreenState extends State<TrackLocationScreen> {
  static const String _directionsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );
  static const bool _logRealtime = true;

  GoogleMapController? _mapController;
  Position? _currentPosition;
  String? _error;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  BitmapDescriptor? _destinationIcon;
  StreamSubscription<Position>? _positionSub;
  Timer? _periodicPushTimer;
  bool _trackingEnabled = true;
  bool _arrivalDialogShowing = false;
  bool _arrivalDialogDismissed = false;
  bool _arrivalConfirmed = false;
  DatabaseReference? _locationRef;
  DateTime _lastRealtimePush = DateTime.fromMillisecondsSinceEpoch(0);

  String get _cardName {
    final value = _victimName ?? widget.victimName?.trim();
    if (value != null && value.isNotEmpty) return value;
    return 'Victim';
  }

  String get _cardAddress {
    final value = _victimAddress ?? widget.victimAddress?.trim();
    if (value != null && value.isNotEmpty) return value;
    return '${widget.destLat.toStringAsFixed(5)}, ${widget.destLng.toStringAsFixed(5)}';
  }

  String? _victimName;
  String? _victimAddress;
  String? _victimPhotoUrl;
  String? _victimPhone;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission denied');
        return;
      }

      _destinationIcon = await _loadDisasterIcon();

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });

      // Prepare RTDB path for this rescuer if signed-in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _locationRef = FirebaseDatabase.instance.ref(
          'rescuer_locations/${user.uid}',
        );
        try {
          await _locationRef!.onDisconnect().remove();
          if (_logRealtime) {
            debugPrint(
              'RTDB onDisconnect remove attached for rescuer_locations/${user.uid}',
            );
          }
        } catch (_) {}
        // Initial push
        await _maybePushRealtime(position);
      }

      await _loadVictimAndAddress();
      _setMarkers(position);
      await _loadRoute(position);
      _moveCamera(position);
      _checkProximity(position);
      _startPositionStream();
      _startPeriodicPush();
    } catch (e) {
      setState(() => _error = 'Failed to load location: $e');
    }
  }

  Future<void> _loadVictimAndAddress() async {
    try {
      final info = await widget.victimRepository.fetchBySenderId(
        widget.senderId,
      );
      final addr = await widget.locationResolver.resolve(
        '${widget.destLat},${widget.destLng}',
      );
      setState(() {
        _victimName = info.name;
        _victimPhone = info.phone;
        _victimPhotoUrl = info.photoUrl;
        _victimAddress = addr.isNotEmpty ? addr : info.address;
      });
    } catch (_) {
      // ignore errors, fallback handled by getters
    }
  }

  void _startPositionStream() {
    _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((pos) async {
          setState(() => _currentPosition = pos);
          _setMarkers(pos);
          await _loadRoute(pos);
          _moveCamera(pos);
          _checkProximity(pos);
          await _maybePushRealtime(pos);
        });
  }

  void _startPeriodicPush() {
    _periodicPushTimer?.cancel();
    _periodicPushTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshPositionAndPush();
    });
  }

  Future<void> _refreshPositionAndPush() async {
    try {
      final fresh = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = fresh);
      await _maybePushRealtime(fresh, force: true);
    } catch (e) {
      if (_logRealtime) {
        debugPrint('RTDB skip: failed to refresh position ($e)');
      }
    }
  }

  Future<void> _maybePushRealtime(Position pos, {bool force = false}) async {
    if (!_trackingEnabled) {
      if (_logRealtime) debugPrint('RTDB skip: tracking disabled');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (_logRealtime) debugPrint('RTDB skip: no signed-in user');
      return;
    }
    final now = DateTime.now();
    if (!force && now.difference(_lastRealtimePush).inSeconds < 3) {
      if (_logRealtime) debugPrint('RTDB skip: throttle window');
      return;
    }
    _lastRealtimePush = now;

    if (_locationRef == null) {
      _locationRef = FirebaseDatabase.instance.ref(
        'rescuer_locations/${user.uid}',
      );
      try {
        await _locationRef!.onDisconnect().remove();
        if (_logRealtime) {
          debugPrint(
            'RTDB onDisconnect remove attached (lazy) for rescuer_locations/${user.uid}',
          );
        }
      } catch (_) {}
    }

    try {
      await _locationRef!.update({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'speed': pos.speed,
        'heading': pos.heading,
        'updatedAt': ServerValue.timestamp,
      });
      if (_logRealtime) {
        debugPrint(
          'RTDB update pushed: ${pos.latitude}, ${pos.longitude} (acc=${pos.accuracy})',
        );
      }
    } catch (e) {
      if (_logRealtime) debugPrint('RTDB update failed: $e');
      // swallow errors to avoid impacting UI updates
    }
  }

  void _setMarkers(Position current) {
    _markers
      ..clear()
      ..add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(widget.destLat, widget.destLng),
          infoWindow: InfoWindow(title: widget.destinationLabel),
          icon:
              _destinationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

    _circles
      ..clear()
      ..add(
        Circle(
          circleId: const CircleId('current'),
          center: LatLng(current.latitude, current.longitude),
          radius: 6, // meters; renders as dot
          fillColor: const Color(0xFF4285F4).withOpacity(0.7),
          strokeColor: const Color(0xFF4285F4),
          strokeWidth: 2,
        ),
      );
    setState(() {});
  }

  Future<void> _loadRoute(Position origin) async {
    // Skip network call if no key; still show markers.
    if (_directionsApiKey.isEmpty) {
      setState(
        () =>
            _error = 'Directions API key is missing. Set GOOGLE_MAPS_API_KEY.',
      );
      return;
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${origin.latitude},${origin.longitude}'
      '&destination=${widget.destLat},${widget.destLng}'
      '&mode=driving'
      '&key=$_directionsApiKey',
    );

    try {
      final res = await http.get(url);
      if (res.statusCode != 200) {
        setState(() => _error = 'Directions request failed: ${res.statusCode}');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        setState(() => _error = 'No route found. Showing markers only.');
        return;
      }

      final overview = routes.first['overview_polyline']?['points'] as String?;
      if (overview == null || overview.isEmpty) {
        setState(() => _error = 'No polyline in route. Showing markers only.');
        return;
      }

      final points = _decodePolyline(overview);
      _polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: Colors.blue,
            width: 6,
          ),
        );
      setState(() {});
    } catch (e) {
      setState(() => _error = 'Directions failed. Showing markers only. ($e)');
    }
  }

  void _moveCamera(Position origin) {
    if (_mapController == null) return;
    final bounds = _boundsFromLatLngs([
      LatLng(origin.latitude, origin.longitude),
      LatLng(widget.destLat, widget.destLng),
    ]);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  LatLngBounds _boundsFromLatLngs(List<LatLng> list) {
    if (list.isEmpty) {
      return LatLngBounds(southwest: LatLng(0, 0), northeast: LatLng(0, 0));
    }

    double minLat = list.first.latitude;
    double maxLat = list.first.latitude;
    double minLng = list.first.longitude;
    double maxLng = list.first.longitude;

    for (final latLng in list.skip(1)) {
      if (latLng.latitude > maxLat) maxLat = latLng.latitude;
      if (latLng.latitude < minLat) minLat = latLng.latitude;
      if (latLng.longitude > maxLng) maxLng = latLng.longitude;
      if (latLng.longitude < minLng) minLng = latLng.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _periodicPushTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _handleMessage(BuildContext context) {
    // Prefer explicit callback if provided, else default to group chat screen
    if (widget.onMessage != null) {
      widget.onMessage!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RescuerGroupChatScreen(groupChatId: widget.groupChatId),
      ),
    );
  }

  void _handleArrived(BuildContext context) {
    if (_arrivalConfirmed) return;
    final pos = _currentPosition;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location unavailable.')),
      );
      return;
    }
    _showArrivalDialog(context, pos);
  }

  Future<void> _handleCall(BuildContext context) async {
    final phone = _victimPhone ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available.')),
      );
      return;
    }
    // Keep leading +, strip everything else that isn't a digit
    final phoneSanitized = phone
        .trim()
        .replaceAll(RegExp(r'[^\d+]'), '')
        .replaceAll(RegExp(r'(?<=.)\+'), '');
    final uri = Uri(scheme: 'tel', path: phoneSanitized);
    final ok = await canLaunchUrl(uri)
        ? await launchUrl(uri, mode: LaunchMode.externalApplication)
        : false;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to start call.')));
    }
  }

  Future<BitmapDescriptor> _loadDisasterIcon() async {
    final type = widget.destinationLabel.toLowerCase();
    String? assetPath;
    if (type.contains('fire')) {
      assetPath = 'assets/markers/fireMarker.png';
    } else if (type.contains('landslide')) {
      assetPath = 'assets/markers/landslideMarker.png';
    } else if (type.contains('tsunami')) {
      assetPath = 'assets/markers/tsunamiMarker.png';
    } else if (type.contains('police')) {
      assetPath = 'assets/markers/policeMarker.png';
    } else if (type.contains('volcano') || type.contains('volcan')) {
      assetPath = 'assets/markers/volcanMarker.png';
    } else if (type.contains('earth') || type.contains('quake')) {
      assetPath = 'assets/markers/earthquakeMarker.png';
    } else if (type.contains('medical') ||
        type.contains('injury') ||
        type.contains('rescue')) {
      assetPath = 'assets/markers/medicalMarker.png';
    } else if (type.contains('typhoon') ||
        type.contains('storm') ||
        type.contains('flood')) {
      assetPath = 'assets/markers/typhoonMarker.png';
    }

    if (assetPath == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }

    try {
      return await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(64, 64)),
        assetPath,
      );
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final latLng = LatLng(lat / 1E5, lng / 1E5);
      poly.add(latLng);
    }

    return poly;
  }

  @override
  Widget build(BuildContext context) {
    final destination = LatLng(widget.destLat, widget.destLng);
    final initialPosition = CameraPosition(target: destination, zoom: 14);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Track Location',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.grey[50],
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        actions: [
          Row(
            children: [
              Text(
                _trackingEnabled ? 'Active' : 'Off',
                style: GoogleFonts.poppins(color: Colors.black, fontSize: 12),
              ),
              Switch(
                value: _trackingEnabled,
                activeThumbColor: Colors.green,
                onChanged: (value) {
                  setState(() => _trackingEnabled = value);
                  if (value) {
                    _startPeriodicPush();
                    final pos = _currentPosition;
                    if (pos != null) {
                      _maybePushRealtime(pos, force: true);
                    }
                  } else {
                    _periodicPushTimer?.cancel();
                  }
                },
              ),
            ],
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Text(
                _error!,
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            )
          : _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: initialPosition,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  markers: _markers,
                  circles: _circles,
                  polylines: _polylines,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_currentPosition != null) {
                      _moveCamera(_currentPosition!);
                    }
                  },
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 50,
                  child: VictimFloatingCard(
                    victimName: _cardName,
                    address: _cardAddress,
                    photoUrl: _victimPhotoUrl,
                    onMessage: () => _handleMessage(context),
                    onArrived: () => _handleArrived(context),
                    onCall: () => _handleCall(context),
                    arrivedEnabled: !_arrivalConfirmed,
                  ),
                ),
              ],
            ),
      floatingActionButton: null,
    );
  }

  void _checkProximity(Position pos) {
    if (_arrivalDialogDismissed) return;
    // Trigger confirmation dialog once when within ~120m of destination.
    final distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      widget.destLat,
      widget.destLng,
    );
    if (distance <= 120 && !_arrivalDialogShowing) {
      _showArrivalDialog(context, pos);
    }
  }

  void _showArrivalDialog(BuildContext context, Position pos) {
    if (_arrivalDialogShowing || _arrivalDialogDismissed) return;
    _arrivalDialogShowing = true;
    final now = DateTime.now();
    final timeString = _formatTimestamp(now);
    final coordString =
        '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirm Arrival?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Timestamp and GPS coordinates have been captured.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  timeString,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  coordString,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await _confirmArrival(context);
                      _arrivalDialogShowing = true;
                      _arrivalDialogDismissed = true;
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirm Arrival',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _arrivalDialogShowing = false;
                      _arrivalDialogDismissed = true;
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black87),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
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

  Future<void> _confirmArrival(BuildContext context) async {
    _arrivalDialogShowing = false;
    _arrivalDialogDismissed = true;
    _arrivalConfirmed = true;
    await _sendArrivalChatMessage();
    if (widget.onArrived != null) {
      widget.onArrived!();
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rescuer arrival recorded.')));
  }

  Future<void> _sendArrivalChatMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final senderName = await _resolveSenderName(user);

    final parentRef = FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.groupChatId);

    final parentSnap = await parentRef.get();
    if (!parentSnap.exists) {
      await parentRef.set({
        'createdAt': Timestamp.now(),
        'createdBy': user.uid,
        'status': 'active',
      });
    }

    final message = ChatMessage(
      senderId: user.uid,
      senderName: senderName,
      message: 'Rescuer Arrived',
      type: 'text',
      sentAt: Timestamp.now(),
    );

    await parentRef.collection('messages').add(message.toMap());
  }

  Future<String> _resolveSenderName(User user) async {
    try {
      final profileSnap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      final data = profileSnap.data();
      if (data != null) {
        final first = (data['firstName'] ?? '').toString().trim();
        final last = (data['lastName'] ?? '').toString().trim();
        final fullName = [
          first,
          last,
        ].where((p) => p.isNotEmpty).join(' ').trim();
        if (fullName.isNotEmpty) return fullName;
        final display = (data['displayName'] ?? data['fullName'] ?? '')
            .toString()
            .trim();
        if (display.isNotEmpty) return display;
      }
    } catch (_) {
      // ignore and fallback
    }
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final emailPrefix = user.email?.split('@').first;
    if (emailPrefix != null && emailPrefix.isNotEmpty) return emailPrefix;
    return 'Rescuer';
  }

  String _formatTimestamp(DateTime now) {
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '${monthNames[now.month - 1]} ${now.day}, ${now.year} • $hour:$minute $period';
  }
}
