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
    this.accountTitle = '',
    this.jazzCashAccount = '',
    this.easyPaisaAccount = '',
    this.raastId = '',
    this.loginMode = 'quick',
    this.autoHours = false,
    this.opensAt = 540,
    this.closesAt = 1260,
    this.pauseWhenNoRiders = false,
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

  /// Bank name, account number / IBAN (multi-line text).
  final String bankDetails;

  /// Name on Alpha LPG's bank and wallet accounts.
  final String accountTitle;
  final String jazzCashAccount;
  final String easyPaisaAccount;

  /// Raast ID (usually a mobile number) for instant bank transfers.
  final String raastId;

  /// How customers sign in: 'quick' (mobile number, no SMS code; works on
  /// Firebase's free plan, so the shop confirms orders by phone) or 'sms'
  /// (one-time code by SMS; needs the paid Firebase plan).
  final String loginMode;

  bool get smsLogin => loginMode == 'sms';

  /// When true, the customer app only takes orders between [opensAt] and
  /// [closesAt] (minutes after midnight, Lahore time).
  final bool autoHours;
  final int opensAt;
  final int closesAt;

  /// When true, orders pause by themselves while no rider is online.
  final bool pauseWhenNoRiders;

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
      accountTitle: m['accountTitle'] as String? ?? d.accountTitle,
      jazzCashAccount: m['jazzCashAccount'] as String? ?? d.jazzCashAccount,
      easyPaisaAccount: m['easyPaisaAccount'] as String? ?? d.easyPaisaAccount,
      raastId: m['raastId'] as String? ?? d.raastId,
      loginMode: m['loginMode'] == 'sms' ? 'sms' : 'quick',
      autoHours: m['autoHours'] as bool? ?? d.autoHours,
      opensAt: (m['opensAt'] as num?)?.toInt() ?? d.opensAt,
      closesAt: (m['closesAt'] as num?)?.toInt() ?? d.closesAt,
      pauseWhenNoRiders: m['pauseWhenNoRiders'] as bool? ?? d.pauseWhenNoRiders,
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
    'accountTitle': accountTitle,
    'jazzCashAccount': jazzCashAccount,
    'easyPaisaAccount': easyPaisaAccount,
    'raastId': raastId,
    'loginMode': loginMode,
    'autoHours': autoHours,
    'opensAt': opensAt,
    'closesAt': closesAt,
    'pauseWhenNoRiders': pauseWhenNoRiders,
  };
}
