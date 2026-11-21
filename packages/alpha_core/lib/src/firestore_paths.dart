/// Every Firestore collection/document path used by the Alpha LPG apps.
///
/// Keep this in sync with `firebase/firestore.rules`.
abstract final class FirestorePaths {
  static const products = 'products';
  static const settingsDoc = 'config/app';
  static const customers = 'customers';
  static String addresses(String uid) => 'customers/$uid/addresses';
  static const orders = 'orders';
  static const quoteRequests = 'quoteRequests';
  static const riders = 'riders';
  static String messages(String orderId) => 'orders/$orderId/messages';
  static String live(String orderId) => 'orders/$orderId/live';
  static const liveDoc = 'rider';
}
