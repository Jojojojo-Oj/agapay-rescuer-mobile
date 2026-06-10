import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/hive/sos_hive_service.dart';

class SosNavigationScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? senderHash;
  final String? dedupeKey;

  const SosNavigationScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.senderHash,
    this.dedupeKey,
  });

  @override
  State<SosNavigationScreen> createState() => _SosNavigationScreenState();
}

class _SosNavigationScreenState extends State<SosNavigationScreen> {
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;

  Position? _position;
  double? _heading;
  double? _smoothedHeading;
  String? _error;
  double _displayTurns = 0;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _compassSub = FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading == null) return;
      setState(() {
        _heading = heading;
        _smoothedHeading = _smoothHeading(_smoothedHeading, heading);
      });
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _startLocationUpdates() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final current = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _position = current;
        });
      }

      _positionSub?.cancel();
      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 2,
            ),
          ).listen((position) {
            if (!mounted) return;
            setState(() {
              _position = position;
            });
          });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  double? _bearingToTarget() {
    if (_position == null) return null;

    final lat1 = _position!.latitude * math.pi / 180;
    final lon1 = _position!.longitude * math.pi / 180;
    final lat2 = widget.latitude * math.pi / 180;
    final lon2 = widget.longitude * math.pi / 180;

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  double? _distanceMeters() {
    if (_position == null) return null;

    return Geolocator.distanceBetween(
      _position!.latitude,
      _position!.longitude,
      widget.latitude,
      widget.longitude,
    );
  }

  double _smoothTurns(double targetTurns) {
    final diff = targetTurns - _displayTurns;
    if (diff.abs() > 0.5) {
      _displayTurns += diff > 0 ? diff - 1 : diff + 1;
    } else {
      _displayTurns += diff;
    }
    return _displayTurns;
  }

  double _smoothHeading(double? current, double next) {
    if (current == null) return next;
    final currentRad = current * math.pi / 180;
    final nextRad = next * math.pi / 180;
    final x = math.cos(nextRad) * 0.2 + math.cos(currentRad) * 0.8;
    final y = math.sin(nextRad) * 0.2 + math.sin(currentRad) * 0.8;
    final blended = math.atan2(y, x) * 180 / math.pi;
    return (blended + 360) % 360;
  }

  Future<void> _onVictimFound() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirm Resolution?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please ensure the rescue\noperation is complete',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Color(0xFF555555)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28A745),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'CONFIRM',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black87, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      final key = widget.dedupeKey;
      if (key != null) {
        await SosHiveService.markResolved(key);
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bearing = _bearingToTarget();
    final distance = _distanceMeters();
    final heading = _smoothedHeading ?? _heading;

    final rotationDegrees = bearing == null
        ? 0
        : heading == null
        ? bearing
        : (bearing - heading);
    final rotationTurns = _smoothTurns(rotationDegrees / 360);

    return Scaffold(
      appBar: AppBar(title: const Text('Navigation')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_error != null)
                Text(
                  _error!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.red),
                ),
              Expanded(
                child: Center(
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    turns: rotationTurns,
                    child: Icon(
                      Icons.navigation,
                      size: 160,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Target: ${widget.latitude.toStringAsFixed(6)}, '
                '${widget.longitude.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.senderHash != null)
                Text(
                  'Sender: ${widget.senderHash}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              Text('Bearing: ${bearing?.toStringAsFixed(1) ?? '--'}°'),
              Text('Heading: ${heading?.toStringAsFixed(1) ?? '--'}°'),
              Text(
                'Distance: ${distance == null ? '--' : distance.toStringAsFixed(1)} m',
              ),
              const SizedBox(height: 12),
              Text(
                'Works offline. Compass uses device sensors.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onVictimFound,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28A745),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'VICTIM FOUND',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
