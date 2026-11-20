/// A delivery address saved by a customer (also copied onto each order).
class Address {
  const Address({
    this.id = '',
    required this.label,
    required this.line1,
    required this.area,
    this.landmark = '',
    this.city = 'Lahore',
    this.lat,
    this.lng,
  });

  final String id;
  final String label; // Home, Restaurant, Office …
  final String line1; // house / shop / street
  final String area; // DHA Phase 5, Gulberg III, Johar Town …
  final String landmark;
  final String city;
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;

  String get oneLine => [
    line1,
    area,
    if (landmark.isNotEmpty) 'near $landmark',
    city,
  ].where((s) => s.trim().isNotEmpty).join(', ');

  Address copyWith({String? id, double? lat, double? lng}) => Address(
    id: id ?? this.id,
    label: label,
    line1: line1,
    area: area,
    landmark: landmark,
    city: city,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
  );

  factory Address.fromMap(String id, Map<String, dynamic> m) => Address(
    id: id,
    label: m['label'] as String? ?? '',
    line1: m['line1'] as String? ?? '',
    area: m['area'] as String? ?? '',
    landmark: m['landmark'] as String? ?? '',
    city: m['city'] as String? ?? 'Lahore',
    lat: (m['lat'] as num?)?.toDouble(),
    lng: (m['lng'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'label': label,
    'line1': line1,
    'area': area,
    'landmark': landmark,
    'city': city,
    'lat': lat,
    'lng': lng,
  };
}
