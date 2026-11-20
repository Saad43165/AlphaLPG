import '../dates.dart';
import 'product.dart';

class CustomerProfile {
  const CustomerProfile({
    required this.uid,
    required this.name,
    required this.phone,
    this.type = CustomerSegment.home,
    this.businessName = '',
    this.businessType = '',
    this.email = '',
    this.createdAt,
  });

  final String uid;
  final String name;
  final String phone;

  /// [CustomerSegment.home] or [CustomerSegment.business].
  final CustomerSegment type;
  final String businessName;

  /// Restaurant / Café, Hotel, Factory … (see QuoteRequest.businessTypes).
  final String businessType;
  final String email;
  final DateTime? createdAt;

  bool get isBusiness => type == CustomerSegment.business;

  String get displayName =>
      isBusiness && businessName.isNotEmpty ? '$name · $businessName' : name;

  CustomerProfile copyWith({
    String? name,
    CustomerSegment? type,
    String? businessName,
    String? businessType,
    String? email,
  }) => CustomerProfile(
    uid: uid,
    name: name ?? this.name,
    phone: phone,
    type: type ?? this.type,
    businessName: businessName ?? this.businessName,
    businessType: businessType ?? this.businessType,
    email: email ?? this.email,
    createdAt: createdAt,
  );

  factory CustomerProfile.fromMap(String uid, Map<String, dynamic> m) =>
      CustomerProfile(
        uid: uid,
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        type: CustomerSegment.parse(m['type'] as String?),
        businessName: m['businessName'] as String? ?? '',
        businessType: m['businessType'] as String? ?? '',
        email: m['email'] as String? ?? '',
        createdAt: readDate(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'type': type.name,
    'businessName': businessName,
    'businessType': businessType,
    'email': email,
  };
}
