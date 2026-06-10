String _canonicalDisasterLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('medical')) return 'medical';
  if (normalized.contains('fire')) return 'fire';
  if (normalized.contains('typhoon')) return 'typhoon';
  if (normalized.contains('earthquake')) return 'earthquake';
  if (normalized.contains('landslide')) return 'landslide';
  if (normalized.contains('tsunami')) return 'tsunami';
  if (normalized.contains('police')) return 'police';
  if (normalized.contains('volcano') || normalized.contains('volcan')) {
    return 'volcano';
  }
  return normalized;
}

dynamic resolveEmergencyAvailabilityFromUserData(Map<String, dynamic> userData) {
  final direct = userData['emergency_availability'];
  if (direct != null) return direct;

  final equipmentCapability = userData['equipmentCapability'];
  if (equipmentCapability is Map<String, dynamic>) {
    return equipmentCapability['emergency_availability'];
  }
  if (equipmentCapability is Map) {
    return equipmentCapability['emergency_availability'];
  }

  return null;
}

Set<String> _normalizedAvailability(dynamic emergencyAvailability) {
  if (emergencyAvailability is! Iterable) return <String>{};

  return emergencyAvailability
      .whereType<String>()
      .map(_canonicalDisasterLabel)
      .where((value) => value.isNotEmpty)
      .toSet();
}

bool canRescuerHandleIncident({
  required dynamic emergencyAvailability,
  required String disasterType,
}) {
  final allowed = _normalizedAvailability(emergencyAvailability);
  if (allowed.contains('all') || allowed.contains('any')) return true;
  if (allowed.isEmpty) return false;

  final incidentType = _canonicalDisasterLabel(disasterType);
  return allowed.contains(incidentType);
}
