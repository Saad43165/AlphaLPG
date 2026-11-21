import '../dates.dart';

/// A delivery rider, stored in `riders/{uid}`. Created by the shop owner;
/// a rider can only sign in to the rider app while [active] is true.
class RiderProfile {
  const RiderProfile({
    required this.uid,
    required this.name,
    required this.phone,
    this.vehicle = 'Motorbike',
    this.active = true,
    this.online = false,
    this.lastSeen,
    this.lat,
    this.lng,
  });

  final String uid;
  final String name;
  final String phone;
  final String vehicle;

  /// Switched off by the owner to block a rider.
  final bool active;

  /// The rider's own "on shift" switch. Only online riders get new jobs.
  final bool online;

  /// Last sign of life from the rider app (a heartbeat while online).
  final DateTime? lastSeen;

  /// Last known position (updated with the heartbeat while online). Used to
  /// suggest the nearest rider. Only the shop can read it.
  final double? lat;
  final double? lng;

  bool get hasPosition => lat != null && lng != null;

  /// A rider is really available only while their app keeps reporting in.
  bool isLive([DateTime? now]) =>
      active &&
      online &&
      lastSeen != null &&
      (now ?? DateTime.now()).difference(lastSeen!) <
          const Duration(minutes: 3);

  factory RiderProfile.fromMap(String uid, Map<String, dynamic> m) =>
      RiderProfile(
        uid: uid,
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        vehicle: m['vehicle'] as String? ?? 'Motorbike',
        active: m['active'] as bool? ?? true,
        online: m['online'] as bool? ?? false,
        lastSeen: readDate(m['lastSeen']),
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'vehicle': vehicle,
    'active': active,
    'online': online,
  };
}

/// Where a rider is right now, shared with the customer while delivering.
/// Stored in `orders/{id}/live/rider`.
class RiderLocation {
  const RiderLocation({
    required this.lat,
    required this.lng,
    this.heading = 0,
    this.speedKmh = 0,
    this.accuracy = 0,
    this.updatedAt,
  });

  final double lat;
  final double lng;

  /// Direction of travel in degrees.
  final double heading;
  final double speedKmh;

  /// GPS accuracy in metres.
  final double accuracy;
  final DateTime? updatedAt;

  /// True if the last update is recent enough to trust.
  bool isFresh([DateTime? now]) =>
      updatedAt != null &&
      (now ?? DateTime.now()).difference(updatedAt!) <
          const Duration(minutes: 2);

  factory RiderLocation.fromMap(Map<String, dynamic> m) => RiderLocation(
    lat: (m['lat'] as num?)?.toDouble() ?? 0,
    lng: (m['lng'] as num?)?.toDouble() ?? 0,
    heading: (m['heading'] as num?)?.toDouble() ?? 0,
    speedKmh: (m['speedKmh'] as num?)?.toDouble() ?? 0,
    accuracy: (m['accuracy'] as num?)?.toDouble() ?? 0,
    updatedAt: readDate(m['updatedAt']),
  );

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'heading': heading,
    'speedKmh': speedKmh,
    'accuracy': accuracy,
  };
}
