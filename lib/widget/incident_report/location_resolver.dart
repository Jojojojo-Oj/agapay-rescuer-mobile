import 'package:geocoding/geocoding.dart' as geo;

class LocationResolver {
  const LocationResolver();

  static final Map<String, Future<String>> _cache = {};

  Future<String> resolve(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return Future.value('Location unavailable');

    final coords = _parseLatLng(normalized);
    if (coords == null) return Future.value(normalized);

    final cached = _cache[normalized];
    if (cached != null) return cached;

    final future = _reverseGeocode(coords)
        .then((resolved) => resolved != null && resolved.isNotEmpty ? resolved : normalized)
        .catchError((_) => normalized);

    _cache[normalized] = future;
    return future;
  }

  _LatLng? _parseLatLng(String raw) {
    final parts = raw.split(',');
    if (parts.length != 2) return null;

    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;

    return _LatLng(lat, lng);
  }

  Future<String?> _reverseGeocode(_LatLng coords) async {
    final placemarks = await geo.placemarkFromCoordinates(coords.lat, coords.lng);
    final place = placemarks.isNotEmpty ? placemarks.first : null;
    if (place == null) return null;

    final parts = [
      place.street,
      place.subLocality,
      place.locality,
      place.administrativeArea,
      place.country,
    ].where((part) => part != null && part.isNotEmpty).map((part) => part!).toList();

    if (parts.isEmpty) return null;

    return parts.join(', ');
  }
}

class _LatLng {
  final double lat;
  final double lng;

  const _LatLng(this.lat, this.lng);
}
