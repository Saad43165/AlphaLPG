import '../dates.dart';

/// A bulk / commercial supply enquiry (restaurants, hotels, factories).
class QuoteRequest {
  const QuoteRequest({
    this.id = '',
    required this.customerId,
    required this.businessName,
    required this.contactName,
    required this.phone,
    required this.businessType,
    required this.monthlyKg,
    this.preferredSize = '45.4 KG',
    this.area = '',
    this.notes = '',
    this.status = 'new',
    this.createdAt,
  });

  final String id;
  final String customerId;
  final String businessName;
  final String contactName;
  final String phone;
  final String businessType; // Restaurant, Hotel, Factory …
  final int monthlyKg;
  final String preferredSize;
  final String area;
  final String notes;
  final String status; // new, contacted, won, lost
  final DateTime? createdAt;

  static const businessTypes = [
    'Restaurant / Café',
    'Hotel / Marriage hall',
    'Bakery / Sweets',
    'Factory / Industrial',
    'Hostel / Office',
    'Other',
  ];

  factory QuoteRequest.fromMap(String id, Map<String, dynamic> m) =>
      QuoteRequest(
        id: id,
        customerId: m['customerId'] as String? ?? '',
        businessName: m['businessName'] as String? ?? '',
        contactName: m['contactName'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        businessType: m['businessType'] as String? ?? '',
        monthlyKg: (m['monthlyKg'] as num?)?.toInt() ?? 0,
        preferredSize: m['preferredSize'] as String? ?? '',
        area: m['area'] as String? ?? '',
        notes: m['notes'] as String? ?? '',
        status: m['status'] as String? ?? 'new',
        createdAt: readDate(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
    'customerId': customerId,
    'businessName': businessName,
    'contactName': contactName,
    'phone': phone,
    'businessType': businessType,
    'monthlyKg': monthlyKg,
    'preferredSize': preferredSize,
    'area': area,
    'notes': notes,
    'status': status,
  };
}
