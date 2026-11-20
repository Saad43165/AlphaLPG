/// Business settings in `config/app`, editable from the admin app so prices,
/// fees and contact details never need an app update.
class AppSettings {
  const AppSettings({
    this.acceptingOrders = true,
    this.closedMessage = '',
    this.deliveryFee = 0,
    this.freeDeliveryFrom = 0,
    this.minOrderTotal = 0,
    this.maxCylindersPerOrder = 20,
    this.phone = '03085745740',
    this.whatsapp = '923085745740',
    this.email = 'info@alphalpg.pk',
    this.shopAddress = 'Shop # 1, Service Road, Opposite Dolmen Mall, Lahore',
    this.openingHours = '9:00 am – 9:00 pm, every day',
    this.serviceAreas = const [],
    this.bankDetails = '',
  });

  final bool acceptingOrders;
  final String closedMessage;
  final int deliveryFee;

  /// Subtotal from which delivery is free. 0 disables free delivery.
  final int freeDeliveryFrom;
  final int minOrderTotal;
  final int maxCylindersPerOrder;
  final String phone;

  /// International format without "+", for wa.me links.
  final String whatsapp;
  final String email;
  final String shopAddress;
  final String openingHours;

  /// Areas of Lahore served. Empty means "all of Lahore".
  final List<String> serviceAreas;
  final String bankDetails;

  factory AppSettings.fromMap(Map<String, dynamic> m) {
    const d = AppSettings();
    return AppSettings(
      acceptingOrders: m['acceptingOrders'] as bool? ?? d.acceptingOrders,
      closedMessage: m['closedMessage'] as String? ?? d.closedMessage,
      deliveryFee: (m['deliveryFee'] as num?)?.round() ?? d.deliveryFee,
      freeDeliveryFrom:
          (m['freeDeliveryFrom'] as num?)?.round() ?? d.freeDeliveryFrom,
      minOrderTotal: (m['minOrderTotal'] as num?)?.round() ?? d.minOrderTotal,
      maxCylindersPerOrder:
          (m['maxCylindersPerOrder'] as num?)?.toInt() ??
          d.maxCylindersPerOrder,
      phone: m['phone'] as String? ?? d.phone,
      whatsapp: m['whatsapp'] as String? ?? d.whatsapp,
      email: m['email'] as String? ?? d.email,
      shopAddress: m['shopAddress'] as String? ?? d.shopAddress,
      openingHours: m['openingHours'] as String? ?? d.openingHours,
      serviceAreas: [
        for (final a in (m['serviceAreas'] as List? ?? const [])) '$a',
      ],
      bankDetails: m['bankDetails'] as String? ?? d.bankDetails,
    );
  }

  Map<String, dynamic> toMap() => {
    'acceptingOrders': acceptingOrders,
    'closedMessage': closedMessage,
    'deliveryFee': deliveryFee,
    'freeDeliveryFrom': freeDeliveryFrom,
    'minOrderTotal': minOrderTotal,
    'maxCylindersPerOrder': maxCylindersPerOrder,
    'phone': phone,
    'whatsapp': whatsapp,
    'email': email,
    'shopAddress': shopAddress,
    'openingHours': openingHours,
    'serviceAreas': serviceAreas,
    'bankDetails': bankDetails,
  };
}
