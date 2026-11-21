import '../dates.dart';

/// What a [LedgerEntry] records for a customer.
enum LedgerKind {
  /// Security deposit taken for a cylinder (Rs).
  deposit('Deposit taken'),

  /// Deposit given back (Rs).
  depositRefund('Deposit refunded'),

  /// The customer still holds this many of our empty cylinders.
  emptiesOwed('Empties owed'),

  /// The customer brought empties back.
  emptiesReturned('Empties returned');

  const LedgerKind(this.label);
  final String label;

  static LedgerKind parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => deposit);
}

/// One line in a customer's cylinder/deposit account (`ledger/{id}`).
class LedgerEntry {
  const LedgerEntry({
    this.id = '',
    required this.customerId,
    this.customerName = '',
    required this.kind,
    this.amount = 0,
    this.empties = 0,
    this.note = '',
    this.by = '',
    this.at,
  });

  final String id;
  final String customerId;
  final String customerName;
  final LedgerKind kind;
  final int amount;
  final int empties;
  final String note;
  final String by;
  final DateTime? at;

  factory LedgerEntry.fromMap(String id, Map<String, dynamic> m) => LedgerEntry(
    id: id,
    customerId: m['customerId'] as String? ?? '',
    customerName: m['customerName'] as String? ?? '',
    kind: LedgerKind.parse(m['kind'] as String?),
    amount: (m['amount'] as num?)?.round() ?? 0,
    empties: (m['empties'] as num?)?.round() ?? 0,
    note: m['note'] as String? ?? '',
    by: m['by'] as String? ?? '',
    at: readDate(m['at']),
  );

  Map<String, dynamic> toMap() => {
    'customerId': customerId,
    'customerName': customerName,
    'kind': kind.name,
    'amount': amount,
    'empties': empties,
    'note': note,
    'by': by,
  };
}

/// What a customer holds / owes, from orders and ledger entries.
class CustomerBalance {
  const CustomerBalance({this.deposit = 0, this.emptiesOwed = 0});

  /// Deposit money the shop is holding for this customer (Rs).
  final int deposit;

  /// Empty cylinders this customer still has to return.
  final int emptiesOwed;
}

/// A rider handing the cash they collected to the shop (`handovers/{id}`).
class CashHandover {
  const CashHandover({
    this.id = '',
    required this.riderId,
    this.riderName = '',
    required this.amount,
    this.note = '',
    this.by = '',
    this.at,
  });

  final String id;
  final String riderId;
  final String riderName;
  final int amount;
  final String note;
  final String by;
  final DateTime? at;

  factory CashHandover.fromMap(String id, Map<String, dynamic> m) =>
      CashHandover(
        id: id,
        riderId: m['riderId'] as String? ?? '',
        riderName: m['riderName'] as String? ?? '',
        amount: (m['amount'] as num?)?.round() ?? 0,
        note: m['note'] as String? ?? '',
        by: m['by'] as String? ?? '',
        at: readDate(m['at']),
      );

  Map<String, dynamic> toMap() => {
    'riderId': riderId,
    'riderName': riderName,
    'amount': amount,
    'note': note,
    'by': by,
  };
}

/// Who did what, for the owner's records (`audit/{id}`).
class AuditEntry {
  const AuditEntry({
    this.id = '',
    required this.by,
    this.byName = '',
    required this.action,
    this.target = '',
    this.detail = '',
    this.at,
  });

  final String id;
  final String by;
  final String byName;
  final String action;
  final String target;
  final String detail;
  final DateTime? at;

  factory AuditEntry.fromMap(String id, Map<String, dynamic> m) => AuditEntry(
    id: id,
    by: m['by'] as String? ?? '',
    byName: m['byName'] as String? ?? '',
    action: m['action'] as String? ?? '',
    target: m['target'] as String? ?? '',
    detail: m['detail'] as String? ?? '',
    at: readDate(m['at']),
  );

  Map<String, dynamic> toMap() => {
    'by': by,
    'byName': byName,
    'action': action,
    'target': target,
    'detail': detail,
  };
}

/// A crash or error reported by one of the apps (`errors/{id}`).
class ErrorEntry {
  const ErrorEntry({
    this.id = '',
    required this.app,
    this.version = '',
    this.uid = '',
    required this.message,
    this.stack = '',
    this.at,
  });

  final String id;
  final String app;
  final String version;
  final String uid;
  final String message;
  final String stack;
  final DateTime? at;

  factory ErrorEntry.fromMap(String id, Map<String, dynamic> m) => ErrorEntry(
    id: id,
    app: m['app'] as String? ?? '',
    version: m['version'] as String? ?? '',
    uid: m['uid'] as String? ?? '',
    message: m['message'] as String? ?? '',
    stack: m['stack'] as String? ?? '',
    at: readDate(m['at']),
  );

  Map<String, dynamic> toMap() => {
    'app': app,
    'version': version,
    'uid': uid,
    'message': message,
    'stack': stack,
  };
}

/// A person who can use the admin app. The owner can do everything; staff
/// cannot change settings, delete products, cancel paid orders or manage
/// other admins (`admins/{uid}`).
class AdminUser {
  const AdminUser({
    required this.uid,
    this.email = '',
    this.name = '',
    this.role = 'owner',
    this.createdAt,
  });

  final String uid;
  final String email;
  final String name;
  final String role;
  final DateTime? createdAt;

  bool get isOwner => role != 'staff';

  factory AdminUser.fromMap(String uid, Map<String, dynamic> m) => AdminUser(
    uid: uid,
    email: m['email'] as String? ?? '',
    name: m['name'] as String? ?? '',
    role: m['role'] == 'staff' ? 'staff' : 'owner',
    createdAt: readDate(m['createdAt']),
  );
}
