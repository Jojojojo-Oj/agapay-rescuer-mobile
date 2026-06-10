import 'dart:async';

import 'package:agapay_rescuers/core/utils/emergency_availability_matcher.dart';
import 'package:agapay_rescuers/widget/incident_card.dart';
import 'package:agapay_rescuers/widget/assignmentCard.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum IncidentFilter {
  all,
  fire,
  medical,
  typhoon,
  earthquake,
  landslide,
  tsunami,
  police,
  volcano,
}

class MapScreen extends StatefulWidget {
  final bool embedded;
  final Map<String, dynamic>? userData;

  const MapScreen({
    super.key,
    this.embedded = false,
    this.userData,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  final LatLng _fallbackCenter = const LatLng(14.5995, 120.9842);
  LatLng? _userLatLng;

  bool _loading = true;
  String? _error;

  IncidentFilter _selectedFilter = IncidentFilter.all;

  /// Firestore
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allIncidents = [];
  final Set<Marker> _incidentMarkers = {};
  StreamSubscription? _incidentSub;
  final AudioPlayer _alertPlayer = AudioPlayer();

  /// Seen / assignment handling
  final Set<String> _seenIncidentIds = {};
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _assignmentQueue = [];
  final Set<String> _queuedIncidentIds = {};
  bool _seenReady = false;
  bool _showingAssignment = false;

  /// Selected incident (card)
  Map<String, dynamic>? _selectedIncident;
  String? _selectedAddress;
  bool _addressLoading = false;

  /// Marker icons
  BitmapDescriptor? _fireIcon;
  BitmapDescriptor? _medicalIcon;
  BitmapDescriptor? _typhoonIcon;
  BitmapDescriptor? _earthquakeIcon;
  BitmapDescriptor? _landslideIcon;
  BitmapDescriptor? _tsunamiIcon;
  BitmapDescriptor? _policeIcon;
  BitmapDescriptor? _volcanoIcon;

  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _initLocation();
    _loadSeenIncidents().then((_) => _listenToActiveIncidents());
  }

  // ─────────────────────────────────────────────
  /// 🔹 FIX: Map Firestore disasterType → enum
  IncidentFilter _mapDisasterTypeToFilter(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('fire')) return IncidentFilter.fire;
    if (v.contains('medical')) return IncidentFilter.medical;
    if (v.contains('typhoon')) return IncidentFilter.typhoon;
    if (v.contains('earthquake')) return IncidentFilter.earthquake;
    if (v.contains('landslide')) return IncidentFilter.landslide;
    if (v.contains('tsunami')) return IncidentFilter.tsunami;
    if (v.contains('police')) return IncidentFilter.police;
    if (v.contains('volcano') || v.contains('volcan')) {
      return IncidentFilter.volcano;
    }
    return IncidentFilter.all;
  }

  bool _isIncidentAvailableToRescuer(Map<String, dynamic> incidentData) {
    final userData = widget.userData;
    if (userData == null) return true;

    final emergencyAvailability = resolveEmergencyAvailabilityFromUserData(
      userData,
    );
    final disasterType = (incidentData['disasterType'] ?? '').toString();

    return canRescuerHandleIncident(
      emergencyAvailability: emergencyAvailability,
      disasterType: disasterType,
    );
  }

  // ─────────────────────────────────────────────
  Future<void> _loadSeenIncidents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _seenIncidentIds.addAll(prefs.getStringList('seen_incident_ids') ?? []);
    } catch (_) {}

    _seenReady = true;
  }

  Future<void> _persistSeenIncidents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('seen_incident_ids', _seenIncidentIds.toList());
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  Future<void> _initLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition();
      _userLatLng = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ─────────────────────────────────────────────
  Future<void> _loadMarkerIcons() async {
    _fireIcon = await _loadIcon('assets/markers/fireMarker.png');
    _medicalIcon = await _loadIcon('assets/markers/medicalMarker.png');
    _typhoonIcon = await _loadIcon('assets/markers/typhoonMarker.png');
    _earthquakeIcon = await _loadIcon('assets/markers/earthquakeMarker.png');
    _landslideIcon = await _loadIcon('assets/markers/landslideMarker.png');
    _tsunamiIcon = await _loadIcon('assets/markers/tsunamiMarker.png');
    _policeIcon = await _loadIcon('assets/markers/policeMarker.png');
    _volcanoIcon = await _loadIcon('assets/markers/volcanMarker.png');
  }

  Future<void> _playIncidentSound() async {
    try {
      await _alertPlayer.stop();
      await _alertPlayer.setReleaseMode(ReleaseMode.stop);
      await _alertPlayer.setVolume(1.0);
      await _alertPlayer.play(AssetSource('sounds/incident_sound.mp3'));
    } catch (_) {}
  }

  Future<BitmapDescriptor> _loadIcon(String path) async {
    return BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(72, 72)),
      path,
    );
  }

  // ─────────────────────────────────────────────
  void _listenToActiveIncidents() {
    _incidentSub = FirebaseFirestore.instance
        .collection('sos_reports')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(
          (snapshot) {
            _allIncidents = snapshot.docs;
            _handleNewIncidents(snapshot.docs);
            _applyFilter();
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _error = 'Unable to load active incidents while offline.';
              _incidentMarkers.clear();
            });
          },
        );
  }

  void _handleNewIncidents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (!_seenReady) return;

    var hasNewIncident = false;

    for (final doc in docs) {
      if (_seenIncidentIds.contains(doc.id)) continue;
      _seenIncidentIds.add(doc.id);
      hasNewIncident = true;
      _enqueueAssignmentAlert(doc);
    }

    if (hasNewIncident) {
      _persistSeenIncidents();
      _processAssignmentQueue();
    }
  }

  void _enqueueAssignmentAlert(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!_isIncidentAvailableToRescuer(doc.data())) return;
    if (_queuedIncidentIds.contains(doc.id)) return;
    _queuedIncidentIds.add(doc.id);
    _assignmentQueue.add(doc);
  }

  Future<void> _processAssignmentQueue() async {
    if (_showingAssignment || !mounted || _assignmentQueue.isEmpty) return;

    final nextDoc = _assignmentQueue.removeAt(0);
    _queuedIncidentIds.remove(nextDoc.id);

    await _showAssignmentAlert(nextDoc);

    if (!mounted) return;
    _processAssignmentQueue();
  }

  // ─────────────────────────────────────────────
  void _applyFilter() {
    if (!mounted) return;
    final Set<Marker> markers = {};

    for (final doc in _allIncidents) {
      final data = doc.data();
      final rawType = (data['disasterType'] ?? '').toString();
      final incidentFilter = _mapDisasterTypeToFilter(rawType);

      if (_selectedFilter != IncidentFilter.all &&
          incidentFilter != _selectedFilter) {
        continue;
      }

      final parts = data['location'].toString().split(',');
      if (parts.length != 2) continue;

      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat == null || lng == null) continue;

      final position = LatLng(lat, lng);

      markers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: position,
          icon: _iconForFilter(incidentFilter),
          onTap: () => _onIncidentTap(data, position),
        ),
      );
    }

    setState(() {
      _incidentMarkers
        ..clear()
        ..addAll(markers);
    });
  }

  BitmapDescriptor _iconForFilter(IncidentFilter filter) {
    switch (filter) {
      case IncidentFilter.fire:
        return _fireIcon ?? BitmapDescriptor.defaultMarker;
      case IncidentFilter.medical:
        return _medicalIcon ?? BitmapDescriptor.defaultMarker;
      case IncidentFilter.typhoon:
        return _typhoonIcon ?? BitmapDescriptor.defaultMarker;
      case IncidentFilter.earthquake:
        return _earthquakeIcon ?? BitmapDescriptor.defaultMarker;
      case IncidentFilter.landslide:
        return _landslideIcon ?? BitmapDescriptor.defaultMarker;
      case IncidentFilter.tsunami:
        return _tsunamiIcon ?? BitmapDescriptor.defaultMarker;
      case IncidentFilter.police:
        return _policeIcon ?? BitmapDescriptor.defaultMarker;
      case IncidentFilter.volcano:
        return _volcanoIcon ?? BitmapDescriptor.defaultMarker;
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  // ─────────────────────────────────────────────
  Future<void> _onIncidentTap(
    Map<String, dynamic> data,
    LatLng position,
  ) async {
    setState(() {
      _selectedIncident = data;
      _selectedAddress = null;
      _addressLoading = true;
    });

    try {
      final placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;

      final place = placemarks.isNotEmpty ? placemarks.first : null;
      _selectedAddress =
          _formatPlacemark(place) ??
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    } catch (_) {}

    if (mounted) {
      setState(() => _addressLoading = false);
    }
  }

  // ─────────────────────────────────────────────
  Future<void> _showAssignmentAlert(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (_showingAssignment || !mounted) return;
    _showingAssignment = true;
    try {
      await _playIncidentSound();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: AssignmentCard(
            type: doc['disasterType'],
            statusLabel: 'Reported',
            incidentCode: doc.id,
            address: doc['location'] ?? 'Location unavailable',
            summary: doc['details'] ?? '',
            countdownSeconds: 180,
            onAcknowledge: () {
              Navigator.of(dialogContext).pop();
            },
            onDecline: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      );
    } finally {
      _showingAssignment = false;
    }
  }

  // ─────────────────────────────────────────────
  String? _formatPlacemark(geo.Placemark? p) {
    if (p == null) return null;
    return [
      p.street,
      p.subLocality,
      p.locality,
      p.administrativeArea,
      p.country,
    ].where((e) => e != null && e.isNotEmpty).join(', ');
  }

  // ─────────────────────────────────────────────
  Widget _buildMap() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _userLatLng ?? _fallbackCenter,
            zoom: 12,
          ),
          markers: _incidentMarkers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onTap: (_) => setState(() {
            _selectedIncident = null;
            _selectedAddress = null;
          }),
          onMapCreated: (controller) {
            if (!_mapController.isCompleted) {
              _mapController.complete(controller);
            }
          },
        ),

        if (_selectedIncident != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedScale(
              scale: 0.9,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: IncidentCard(
                type: _selectedIncident!['disasterType'],
                status: 'Active',
                title: '${_selectedIncident!['disasterType']} Incident',
                location: _addressLoading
                    ? 'Finding address...'
                    : (_selectedAddress ??
                          _selectedIncident!['location'] ??
                          'Location unavailable'),
                description: _selectedIncident!['details'] ?? '',
                reportedTime: 'Reported at ${_selectedIncident!['time'] ?? ''}',
                icon: _incidentIcon(_selectedIncident!['disasterType']),
                headerColor: _incidentColor(_selectedIncident!['disasterType']),
              ),
            ),
          ),
      ],
    );
  }

  IconData _incidentIcon(String? type) {
    final f = _mapDisasterTypeToFilter(type ?? '');
    switch (f) {
      case IncidentFilter.medical:
        return Icons.medical_services;
      case IncidentFilter.typhoon:
        return Icons.cyclone;
      case IncidentFilter.earthquake:
        return Icons.house;
      case IncidentFilter.landslide:
        return Icons.terrain;
      case IncidentFilter.tsunami:
        return Icons.waves;
      case IncidentFilter.police:
        return Icons.local_police;
      case IncidentFilter.volcano:
        return Icons.whatshot;
      default:
        return Icons.local_fire_department;
    }
  }

  Color _incidentColor(String? type) {
    final f = _mapDisasterTypeToFilter(type ?? '');
    switch (f) {
      case IncidentFilter.medical:
        return Colors.green;
      case IncidentFilter.typhoon:
        return Colors.blue;
      case IncidentFilter.earthquake:
        return Colors.orange;
      case IncidentFilter.landslide:
        return Colors.brown;
      case IncidentFilter.tsunami:
        return Colors.cyan;
      case IncidentFilter.police:
        return Colors.indigo;
      case IncidentFilter.volcano:
        return Colors.deepOrange;
      default:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    _incidentSub?.cancel();
    _alertPlayer.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Showing today’s incident",
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
          ),
          _buildFilters(),
          Expanded(child: _buildMap()),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  Widget _buildFilters() {
    Widget chip(
      String label,
      IncidentFilter filter,
      IconData icon,
      Color color,
    ) {
      final selected = _selectedFilter == filter;

      return ChoiceChip(
        showCheckmark: false,
        selected: selected,
        selectedColor: color.withOpacity(0.15),
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? color : Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? color : Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? color : Colors.black,
              ),
            ),
          ],
        ),
        onSelected: (_) {
          setState(() {
            _selectedFilter = filter;
            _selectedIncident = null;
            _applyFilter();
          });
        },
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          chip('All', IncidentFilter.all, Icons.apps, Colors.black),
          const SizedBox(width: 8),
          chip(
            'Fire',
            IncidentFilter.fire,
            Icons.local_fire_department,
            Colors.red,
          ),
          const SizedBox(width: 8),
          chip(
            'Medical',
            IncidentFilter.medical,
            Icons.medical_services,
            Colors.green,
          ),
          const SizedBox(width: 8),
          chip('Typhoon', IncidentFilter.typhoon, Icons.cyclone, Colors.blue),
          const SizedBox(width: 8),
          chip(
            'Earthquake',
            IncidentFilter.earthquake,
            Icons.house,
            Colors.orange,
          ),
          const SizedBox(width: 8),
          chip(
            'Landslide',
            IncidentFilter.landslide,
            Icons.terrain,
            Colors.brown,
          ),
          const SizedBox(width: 8),
          chip('Tsunami', IncidentFilter.tsunami, Icons.waves, Colors.cyan),
          const SizedBox(width: 8),
          chip(
            'Police Incident',
            IncidentFilter.police,
            Icons.local_police,
            Colors.indigo,
          ),
          const SizedBox(width: 8),
          chip(
            'Volcano',
            IncidentFilter.volcano,
            Icons.whatshot,
            Colors.deepOrange,
          ),
        ],
      ),
    );
  }
}
