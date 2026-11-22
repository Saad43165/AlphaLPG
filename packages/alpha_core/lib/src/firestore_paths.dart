/// Every Firestore collection/document path used by the Alpha LPG apps.
///
/// Keep this in sync with `firebase/firestore.rules`.
abstract final class FirestorePaths {
  static const products = 'products';
  static const settingsDoc = 'config/app';
  static const customers = 'customers';
  static String addresses(String uid) => 'customers/$uid/addresses';
  static const orders = 'orders';
  static const blocked = 'blocked';
  static const quoteRequests = 'quoteRequests';
  static const riders = 'riders';
  static const coupons = 'coupons';
  static const referralCodes = 'referralCodes';
  static const referralUses = 'referralUses';
  static String loyalty(String uid) => 'loyalty/$uid';
  static String loyaltyEntries(String uid) => 'loyalty/$uid/entries';
  static const statsDoc = 'stats/public';
  static const plans = 'plans';

  /// Where "this customer used this code" is kept (one use per customer).
  /// A friend's "REF-…" code is one use per customer across all friends.
  static String couponUse(String code, String uid) =>
      code.startsWith('REF-') ? 'referralUses/$uid' : 'coupons/$code/uses/$uid';

  /// Public "is this rider on shift" records (no names or numbers).
  static const presence = 'presence';
  static String messages(String orderId) => 'orders/$orderId/messages';
  static String proofs(String orderId) => 'orders/$orderId/proofs';
  static String receipts(String orderId) => 'orders/$orderId/receipts';
  static String chatReads(String orderId) => 'orders/$orderId/reads';
  static String live(String orderId) => 'orders/$orderId/live';
  static const liveDoc = 'rider';
}
