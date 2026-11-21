import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

LpgOrder order() => const LpgOrder(
  customerId: 'u1',
  customerName: 'Ali',
  customerPhone: '+923001234567',
  items: [
    OrderItem(
      productId: 'p',
      name: '11.8kg',
      sizeKg: 11.8,
      type: PurchaseType.refill,
      unitPrice: 3296,
      quantity: 1,
    ),
  ],
  subtotal: 3296,
  deliveryFee: 150,
  total: 3446,
  address: Address(label: 'Home', line1: '1', area: 'DHA'),
);

void main() {
  test('unread counts, preview and "seen" work for every side', () async {
    final store = MemoryStore();
    final orders = OrderRepository.memory(store);
    final id = await orders.place(order());
    final customer = ChatInbox(orders, MessageRole.customer)..follow([id]);
    final rider = ChatInbox(orders, MessageRole.rider)..follow([id]);
    await settle();

    await orders.sendMessage(
      id,
      uid: 'r1',
      role: MessageRole.rider,
      name: 'Imran',
      text: 'I am outside',
    );
    await settle();
    expect(customer.unread(id), 1);
    expect(customer.last(id)!.text, 'I am outside');
    expect(rider.unread(id), 0, reason: 'your own messages are never unread');
    expect(customer.totalUnread, 1);

    // The customer opens the chat: nothing unread, and the rider sees "seen".
    final sentAt = customer.last(id)!.createdAt!;
    await customer.markRead(id);
    await settle();
    expect(customer.unread(id), 0);
    await orders.sendMessage(
      id,
      uid: 'u1',
      role: MessageRole.customer,
      name: 'Ali',
      text: 'Coming down',
    );
    await settle();
    expect(rider.unread(id), 1);
    final mine = rider.last(id)!.createdAt!;
    expect(rider.seenByOthers(id, mine), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await customer.markRead(id);
    await settle();
    expect(rider.seenByOthers(id, sentAt), isTrue);

    // Pinned chats stay followed even if the list moves on.
    rider.follow(const []);
    rider.pin(id);
    await settle();
    expect(rider.messages(id), isNotEmpty);
    rider.dispose();
    customer.dispose();
  });

  test('a chat that cannot be loaded says why, and can be retried', () async {
    final repo = _Denied();
    final inbox = ChatInbox(repo, MessageRole.customer)..follow(['o1']);
    await settle();
    expect(inbox.error('o1'), isNotNull);
    expect(ChatInbox.explain(inbox.error('o1')!), contains('database rules'));
    repo.allow = true;
    inbox.retry('o1');
    await settle();
    expect(inbox.error('o1'), isNull);
    expect(inbox.messages('o1'), isEmpty);
    inbox.dispose();
  });
}

/// Pretends the database refuses to show messages (rules not published).
class _Denied implements OrderRepository {
  bool allow = false;

  @override
  Stream<List<OrderMessage>> watchMessages(String orderId) => allow
      ? Stream.value(const <OrderMessage>[])
      : Stream.error(Exception('[cloud_firestore/permission-denied] no'));

  @override
  Stream<Map<MessageRole, DateTime>> watchChatReads(String orderId) =>
      Stream.value(const {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
