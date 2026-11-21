// Security-rules tests. Run with:  npm run test:rules   (needs Java; starts the Firestore emulator)
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { before, after, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { addDoc, arrayUnion, collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';

const PHONE = '+923001234567';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-alpha',
    firestore: { rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'products/cyl-11-8kg'), { name: '11.8kg', sizeKg: 11.8, refillPrice: 3296, newCylinderPrice: null, active: true, inStock: true });
    await setDoc(doc(db, 'products/cyl-6kg'), { name: '6kg', sizeKg: 6, refillPrice: 1676, newCylinderPrice: 5000, active: true, inStock: true });
    for (const n of ['a', 'b', 'c', 'd']) {
      await setDoc(doc(db, `products/p-${n}`), { name: n, sizeKg: 10, refillPrice: 1000, newCylinderPrice: 4000, active: true, inStock: true });
    }
    await setDoc(doc(db, 'products/cyl-old'), { name: 'old', sizeKg: 5, refillPrice: 100, active: false, inStock: true });
    await setDoc(doc(db, 'config/app'), { acceptingOrders: true, deliveryFee: 150, freeDeliveryFrom: 6000, minOrderTotal: 0, maxCylindersPerOrder: 20 });
    await setDoc(doc(db, 'riders/r1'), { name: 'Imran Khan', phone: '+923005550001', active: true, online: true });
    await setDoc(doc(db, 'riders/r2'), { name: 'Bilal', phone: '+923005550002', active: true, online: true });
    await setDoc(doc(db, 'riders/off'), { name: 'Offline', phone: '+923005550003', active: true, online: false });
    await setDoc(doc(db, 'riders/blocked'), { name: 'Blocked', phone: '+923005550004', active: false, online: true });
    await setDoc(doc(db, 'admins/boss'), { email: 'owner@alphalpg.pk' });
  });
});

const customer = (uid = 'u1', phone = PHONE) => env.authenticatedContext(uid, { phone_number: phone }).firestore();
const quick = (uid = 'u1') => env.authenticatedContext(uid, { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const staff = (uid) => env.authenticatedContext(uid).firestore();
const guest = () => env.unauthenticatedContext().firestore();

const line = (productId, qty, unitPrice, type = 'refill') => ({ productId, name: productId, sizeKg: 11.8, type, unitPrice, quantity: qty });
function order(over = {}) {
  return {
    orderNumber: 'AL-261121-ABCD', customerId: 'u1', customerName: 'Bilal Ahmed', customerPhone: PHONE, customerType: 'home',
    businessName: '', items: [line('cyl-11-8kg', 1, 3296)], subtotal: 3296, deliveryFee: 150, total: 3446,
    address: { label: 'Home', line1: 'Main Boulevard', area: 'Gulberg III', landmark: '', city: 'Lahore', lat: 31.51, lng: 74.34 },
    paymentMethod: 'cashOnDelivery', paymentStatus: 'pending', paymentReference: '', status: 'placed',
    history: [{ status: 'placed', at: new Date(), by: 'u1', note: '' }], scheduledFor: null, notes: '',
    riderId: null, riderName: null, riderPhone: null, cancelReason: '', rating: null, feedback: '',
    cashCollected: null, emptiesCollected: null, cylinderCount: 1, emptiesToCollect: 1,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over,
  };
}
const ev = (status, by) => arrayUnion({ status, at: new Date(), by, note: '' });
async function seedOrder(over = {}, id = 'o1') {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'orders', id), { ...order(), createdAt: new Date(), updatedAt: new Date(), ...over });
  });
}

describe('placing orders', () => {
  it('accepts a correctly priced order', async () => {
    await assertSucceeds(setDoc(doc(customer(), 'orders/o1'), order()));
  });
  it('accepts several lines, free delivery above the limit, a new-cylinder price', async () => {
    const items = [line('cyl-11-8kg', 2, 3296), line('cyl-6kg', 1, 5000, 'newCylinder')];
    await assertSucceeds(setDoc(doc(customer(), 'orders/o2'), order({ items, subtotal: 11592, deliveryFee: 0, total: 11592 })));
  });
  it('accepts the largest cart (6 lines)', async () => {
    const items = ['a', 'b', 'c'].flatMap((n) => [line(`p-${n}`, 1, 1000), line(`p-${n}`, 1, 4000, 'newCylinder')]);
    await assertSucceeds(setDoc(doc(customer(), 'orders/big'), order({ items, subtotal: 15000, deliveryFee: 0, total: 15000, cylinderCount: 6 })));
  });
  it('rejects more than 6 lines', async () => {
    const items = ['a', 'b', 'c', 'd'].flatMap((n) => [line(`p-${n}`, 1, 1000), line(`p-${n}`, 1, 4000, 'newCylinder')]);
    await assertFails(setDoc(doc(customer(), 'orders/big'), order({ items, subtotal: 20000, deliveryFee: 0, total: 20000 })));
  });
  it('rejects a forged unit price', async () => {
    await assertFails(setDoc(doc(customer(), 'orders/o1'), order({ items: [line('cyl-11-8kg', 1, 1)], subtotal: 1, total: 151 })));
  });
  it('rejects a forged total or subtotal', async () => {
    await assertFails(setDoc(doc(customer(), 'orders/o1'), order({ total: 100 })));
    await assertFails(setDoc(doc(customer(), 'orders/o2'), order({ subtotal: 10, total: 160 })));
  });
  it('rejects a wrong delivery fee (free when it should not be, or charged when it should be free)', async () => {
    await assertFails(setDoc(doc(customer(), 'orders/o1'), order({ deliveryFee: 0, total: 3296 })));
    const items = [line('cyl-11-8kg', 2, 3296)];
    await assertFails(setDoc(doc(customer(), 'orders/o2'), order({ items, subtotal: 6592, deliveryFee: 150, total: 6742 })));
  });
  it('rejects inactive or unknown products, zero or huge quantities', async () => {
    await assertFails(setDoc(doc(customer(), 'orders/a'), order({ items: [line('cyl-old', 1, 100)], subtotal: 100, total: 250 })));
    await assertFails(setDoc(doc(customer(), 'orders/b'), order({ items: [line('nope', 1, 100)], subtotal: 100, total: 250 })));
    await assertFails(setDoc(doc(customer(), 'orders/c'), order({ items: [line('cyl-11-8kg', 0, 3296)], subtotal: 0, total: 150 })));
    await assertFails(setDoc(doc(customer(), 'orders/d'), order({ items: [line('cyl-11-8kg', 100, 3296)], subtotal: 329600, deliveryFee: 0, total: 329600 })));
    // (The per-order cylinder limit from the shop settings is enforced by the app and by the shop confirming each order.)
  });
  it('rejects a new-cylinder line for a product that does not sell new cylinders', async () => {
    await assertFails(setDoc(doc(customer(), 'orders/a'), order({ items: [line('cyl-11-8kg', 1, 3296, 'newCylinder')] })));
  });
  it('rejects an order for someone else, from another phone, or from a guest', async () => {
    await assertFails(setDoc(doc(customer('u2'), 'orders/a'), order()));
    await assertFails(setDoc(doc(customer('u1', '+923111111111'), 'orders/b'), order()));
    await assertFails(setDoc(doc(guest(), 'orders/c'), order()));
  });
  it('rejects orders pre-filled with rider, cash, rating, status or extra fields', async () => {
    for (const over of [{ riderId: 'r1' }, { cashCollected: 5000 }, { rating: 5 }, { status: 'delivered' }, { paymentStatus: 'paid' }, { isFree: true }, { cancelReason: 'x' }]) {
      await assertFails(setDoc(doc(customer(), 'orders/x'), order(over)));
    }
  });
  it('rejects oversized text and fake timestamps', async () => {
    await assertFails(setDoc(doc(customer(), 'orders/a'), order({ notes: 'x'.repeat(501) })));
    await assertFails(setDoc(doc(customer(), 'orders/b'), order({ createdAt: new Date('2020-01-01') })));
  });
  it('rejects orders while ordering is paused, and below the minimum', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => updateDoc(doc(ctx.firestore(), 'config/app'), { acceptingOrders: false }));
    await assertFails(setDoc(doc(customer(), 'orders/a'), order()));
    await env.withSecurityRulesDisabled(async (ctx) => updateDoc(doc(ctx.firestore(), 'config/app'), { acceptingOrders: true, minOrderTotal: 5000 }));
    await assertFails(setDoc(doc(customer(), 'orders/b'), order()));
  });
});

describe('quick sign-in customers (no SMS verification)', () => {
  it('can order and keep a profile with a well-formed Pakistani mobile', async () => {
    await assertSucceeds(setDoc(doc(quick(), 'orders/q1'), order({ customerPhone: '+923145459961' })));
    await assertSucceeds(setDoc(doc(quick(), 'customers/u1'), { name: 'Saad', phone: '+923145459961', type: 'home', businessName: '', businessType: '', email: '', createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  });
  it('cannot use a malformed number', async () => {
    for (const bad of ['', 'abc', '03145459961', '+921234567890', '+9231454599611']) {
      await assertFails(setDoc(doc(quick(), 'orders/q2'), order({ customerPhone: bad })));
    }
  });
});

describe('reading orders', () => {
  it('customers see only their own orders', async () => {
    await seedOrder();
    await assertSucceeds(getDoc(doc(customer(), 'orders/o1')));
    await assertFails(getDoc(doc(customer('u2', '+923111111111'), 'orders/o1')));
    await assertFails(getDoc(doc(guest(), 'orders/o1')));
    await assertFails(getDocs(collection(customer('u2'), 'orders')));
    await assertSucceeds(getDocs(query(collection(customer(), 'orders'), where('customerId', '==', 'u1'))));
  });
  it('riders see untaken orders, and their own jobs, but not other riders jobs', async () => {
    await seedOrder();
    await seedOrder({ riderId: 'r2', status: 'assigned' }, 'o2');
    await assertSucceeds(getDoc(doc(staff('r1'), 'orders/o1')));
    await assertFails(getDoc(doc(staff('r1'), 'orders/o2')));
    await assertSucceeds(getDoc(doc(staff('r2'), 'orders/o2')));
    await assertFails(getDoc(doc(staff('blocked'), 'orders/o1')));
    await assertSucceeds(getDocs(query(collection(staff('r1'), 'orders'), where('riderId', '==', null), where('status', 'in', ['placed', 'confirmed']))));
  });
});

describe('customer changes to an existing order', () => {
  it('can cancel while placed, but not after a rider took it', async () => {
    await seedOrder();
    await assertSucceeds(updateDoc(doc(customer(), 'orders/o1'), { status: 'cancelled', cancelReason: 'Ordered by mistake', history: ev('cancelled', 'u1'), updatedAt: serverTimestamp() }));
    await seedOrder({ riderId: 'r1', status: 'assigned' }, 'o2');
    await assertFails(updateDoc(doc(customer(), 'orders/o2'), { status: 'cancelled', cancelReason: 'x', history: ev('cancelled', 'u1'), updatedAt: serverTimestamp() }));
  });
  it('cannot edit price, status or rider', async () => {
    await seedOrder();
    for (const patch of [{ total: 1 }, { status: 'delivered' }, { riderId: 'u1' }, { paymentStatus: 'paid' }, { cashCollected: 9 }]) {
      await assertFails(updateDoc(doc(customer(), 'orders/o1'), { ...patch, updatedAt: serverTimestamp() }));
    }
  });
  it('can add a transaction id to a prepaid order but not to cash-on-delivery', async () => {
    await seedOrder({ paymentMethod: 'jazzCash' });
    await assertSucceeds(updateDoc(doc(customer(), 'orders/o1'), { paymentReference: 'TX123456', updatedAt: serverTimestamp() }));
    await seedOrder({}, 'o2');
    await assertFails(updateDoc(doc(customer(), 'orders/o2'), { paymentReference: 'TX123456', updatedAt: serverTimestamp() }));
  });
  it('can rate a delivered order once, with a valid score', async () => {
    await seedOrder({ status: 'delivered', riderId: 'r1' });
    await assertFails(updateDoc(doc(customer(), 'orders/o1'), { rating: 6, feedback: '', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(customer(), 'orders/o1'), { rating: 5, feedback: 'Great', updatedAt: serverTimestamp() }));
    await seedOrder({ status: 'delivered', riderId: 'r1', rating: 4 }, 'o2');
    await assertFails(updateDoc(doc(customer(), 'orders/o2'), { rating: 5, feedback: '', updatedAt: serverTimestamp() }));
  });
  it('can never delete an order', async () => {
    await seedOrder();
    await assertFails(deleteDoc(doc(customer(), 'orders/o1')));
    await assertFails(deleteDoc(doc(staff('boss'), 'orders/o1')));
    await assertFails(deleteDoc(doc(staff('r1'), 'orders/o1')));
  });
});

describe('rider workflow', () => {
  const accept = (uid, extra = {}) => updateDoc(doc(staff(uid), 'orders/o1'), {
    riderId: uid, riderName: uid === 'r1' ? 'Imran Khan' : 'Bilal', riderPhone: uid === 'r1' ? '+923005550001' : '+923005550002',
    status: 'assigned', history: ev('assigned', uid), updatedAt: serverTimestamp(), ...extra,
  });
  it('an online rider accepts, a second rider is too late', async () => {
    await seedOrder();
    await assertSucceeds(accept('r1'));
    await assertFails(accept('r2'));
  });
  it('an offline, blocked, or name-spoofing rider cannot accept', async () => {
    await seedOrder();
    await assertFails(accept('off'));
    await assertFails(accept('blocked'));
    await assertFails(accept('r1', { riderName: 'Someone Else' }));
    await assertFails(accept('r1', { riderId: 'r2' }));
  });
  it('start, then complete with cash: cash on delivery becomes paid', async () => {
    await seedOrder({ riderId: 'r1', riderName: 'Imran Khan', status: 'assigned' });
    await assertSucceeds(updateDoc(doc(staff('r1'), 'orders/o1'), { status: 'outForDelivery', history: ev('outForDelivery', 'r1'), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(staff('r1'), 'orders/o1'), { status: 'delivered', cashCollected: 3446, emptiesCollected: 1, paymentStatus: 'paid', history: ev('delivered', 'r1'), updatedAt: serverTimestamp() }));
  });
  it('cannot skip a step, reopen a delivered order, or use another riders order', async () => {
    await seedOrder({ riderId: 'r1', status: 'assigned' });
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o1'), { status: 'delivered', cashCollected: 1, emptiesCollected: 0, history: ev('delivered', 'r1'), updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(staff('r2'), 'orders/o1'), { status: 'outForDelivery', history: ev('outForDelivery', 'r2'), updatedAt: serverTimestamp() }));
    await seedOrder({ riderId: 'r1', status: 'delivered', cashCollected: 3446 }, 'o2');
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o2'), { status: 'outForDelivery', history: ev('outForDelivery', 'r1'), updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o2'), { cashCollected: 1, updatedAt: serverTimestamp() }));
  });
  it('cannot mark a prepaid order paid, use bad numbers, or change the price', async () => {
    await seedOrder({ riderId: 'r1', status: 'outForDelivery', paymentMethod: 'bankTransfer' });
    const base = { status: 'delivered', history: ev('delivered', 'r1'), updatedAt: serverTimestamp() };
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o1'), { ...base, cashCollected: 0, emptiesCollected: 0, paymentStatus: 'paid' }));
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o1'), { ...base, cashCollected: -5, emptiesCollected: 0 }));
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o1'), { ...base, cashCollected: 0, emptiesCollected: 500 }));
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o1'), { ...base, cashCollected: 0, emptiesCollected: 0, total: 1 }));
    // Unpaid online order: the rider cannot finish it at all.
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o1'), { ...base, cashCollected: 0, emptiesCollected: 1 }));
    // Once the shop confirmed the payment, the delivery goes through.
    await seedOrder({ riderId: 'r1', status: 'outForDelivery', paymentMethod: 'bankTransfer', paymentStatus: 'paid' }, 'o3');
    await assertSucceeds(updateDoc(doc(staff('r1'), 'orders/o3'), { ...base, cashCollected: 0, emptiesCollected: 1 }));
  });
});

describe('arrival and handing a job back', () => {
  it('the delivering rider marks arrival once; others and customers cannot', async () => {
    await seedOrder({ riderId: 'r1', riderName: 'Imran Khan', status: 'outForDelivery' });
    await assertFails(updateDoc(doc(staff('r2'), 'orders/o1'), { arrivedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(customer(), 'orders/o1'), { arrivedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o1'), { arrivedAt: new Date(), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(staff('r1'), 'orders/o1'), { arrivedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o1'), { arrivedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  });
  it('arrival is only possible while the order is on the way', async () => {
    await seedOrder({ riderId: 'r1', status: 'assigned' });
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o1'), { arrivedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  });
  it('a rider can hand back an assigned job, which becomes open again', async () => {
    await seedOrder({ riderId: 'r1', riderName: 'Imran Khan', riderPhone: '+923005550001', status: 'assigned' });
    const back = { status: 'confirmed', riderId: null, riderName: null, riderPhone: null, history: ev('confirmed', 'r1'), updatedAt: serverTimestamp() };
    await assertFails(updateDoc(doc(staff('r2'), 'orders/o1'), back));
    await assertSucceeds(updateDoc(doc(staff('r1'), 'orders/o1'), back));
    // Another online rider can now take it.
    await assertSucceeds(updateDoc(doc(staff('r2'), 'orders/o1'), {
      riderId: 'r2', riderName: 'Bilal', riderPhone: '+923005550002', status: 'assigned', history: ev('assigned', 'r2'), updatedAt: serverTimestamp(),
    }));
  });
  it('a job that is already on the way cannot be handed back', async () => {
    await seedOrder({ riderId: 'r1', status: 'outForDelivery' });
    await assertFails(updateDoc(doc(staff('r1'), 'orders/o1'), { status: 'confirmed', riderId: null, riderName: null, riderPhone: null, history: ev('confirmed', 'r1'), updatedAt: serverTimestamp() }));
  });
});

describe('the whole journey across the three apps', () => {
  it('customer orders → admin confirms and assigns → rider delivers and is paid → customer rates', async () => {
    // Customer app places the order.
    await assertSucceeds(setDoc(doc(customer(), 'orders/j1'), order()));
    const mine = await getDocs(query(collection(customer(), 'orders'), where('customerId', '==', 'u1')));
    assert.equal(mine.size, 1);
    // Admin app sees it, confirms, assigns a rider.
    await assertSucceeds(getDoc(doc(staff('boss'), 'orders/j1')));
    await assertSucceeds(updateDoc(doc(staff('boss'), 'orders/j1'), { status: 'confirmed', history: ev('confirmed', 'boss'), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(staff('boss'), 'orders/j1'), { riderId: 'r1', riderName: 'Imran Khan', riderPhone: '+923005550001', status: 'assigned', history: ev('assigned', 'boss'), updatedAt: serverTimestamp() }));
    // Rider app: sees the job, starts, shares location.
    await assertSucceeds(getDoc(doc(staff('r1'), 'orders/j1')));
    await assertSucceeds(updateDoc(doc(staff('r1'), 'orders/j1'), { status: 'outForDelivery', history: ev('outForDelivery', 'r1'), updatedAt: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(staff('r1'), 'orders/j1/live/rider'), { lat: 31.51, lng: 74.34, heading: 0, speedKmh: 0, accuracy: 12, updatedAt: serverTimestamp() }));
    // Customer app and admin app both see the rider.
    const live = await assertSucceeds(getDoc(doc(customer(), 'orders/j1/live/rider')));
    assert.equal(live.data().lat, 31.51);
    await assertSucceeds(getDoc(doc(staff('boss'), 'orders/j1/live/rider')));
    // Rider arrives, collects cash (cash on delivery → paid).
    await assertSucceeds(updateDoc(doc(staff('r1'), 'orders/j1'), { arrivedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(staff('r1'), 'orders/j1'), { status: 'delivered', cashCollected: 3446, emptiesCollected: 1, paymentStatus: 'paid', history: ev('delivered', 'r1'), updatedAt: serverTimestamp() }));
    // Customer sees it paid and rates it.
    const done = await getDoc(doc(customer(), 'orders/j1'));
    assert.equal(done.data().status, 'delivered');
    assert.equal(done.data().paymentStatus, 'paid');
    assert.ok(done.data().arrivedAt);
    await assertSucceeds(updateDoc(doc(customer(), 'orders/j1'), { rating: 5, feedback: 'Fast', updatedAt: serverTimestamp() }));
  });
  it('wallet payment: the customer adds the transaction ID, the admin marks it paid', async () => {
    await assertSucceeds(setDoc(doc(customer(), 'orders/j2'), order({ paymentMethod: 'jazzCash' })));
    await assertSucceeds(updateDoc(doc(customer(), 'orders/j2'), { paymentReference: 'TX1234567', updatedAt: serverTimestamp() }));
    // The customer cannot mark it paid; the admin can.
    await assertFails(updateDoc(doc(customer(), 'orders/j2'), { paymentStatus: 'paid', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(staff('boss'), 'orders/j2'), { paymentStatus: 'paid', updatedAt: serverTimestamp() }));
  });
});

describe('order chat', () => {
  const msg = (uid, role, over = {}) => ({ uid, role, name: 'X', text: 'Hello', createdAt: serverTimestamp(), ...over });
  it('the customer, the assigned rider and the shop can talk; strangers cannot', async () => {
    await seedOrder({ riderId: 'r1', riderName: 'Imran Khan', status: 'assigned' });
    await assertSucceeds(addDoc(collection(customer(), 'orders/o1/messages'), msg('u1', 'customer')));
    await assertSucceeds(addDoc(collection(staff('r1'), 'orders/o1/messages'), msg('r1', 'rider')));
    await assertSucceeds(addDoc(collection(staff('boss'), 'orders/o1/messages'), msg('boss', 'admin')));
    await assertSucceeds(getDocs(collection(customer(), 'orders/o1/messages')));
    await assertSucceeds(getDocs(collection(staff('r1'), 'orders/o1/messages')));
    await assertFails(getDocs(collection(customer('u2', '+923111111111'), 'orders/o1/messages')));
    await assertFails(getDocs(collection(staff('r2'), 'orders/o1/messages')));
    await assertFails(addDoc(collection(staff('r2'), 'orders/o1/messages'), msg('r2', 'rider')));
    await assertFails(addDoc(collection(customer('u2', '+923111111111'), 'orders/o1/messages'), msg('u2', 'customer')));
  });
  it('nobody can write as someone else, or send huge or empty messages', async () => {
    await seedOrder({ riderId: 'r1', status: 'assigned' });
    await assertFails(addDoc(collection(customer(), 'orders/o1/messages'), msg('u1', 'admin')));
    await assertFails(addDoc(collection(customer(), 'orders/o1/messages'), msg('u1', 'rider')));
    await assertFails(addDoc(collection(staff('r1'), 'orders/o1/messages'), msg('r1', 'admin')));
    await assertFails(addDoc(collection(customer(), 'orders/o1/messages'), msg('boss', 'customer')));
    await assertFails(addDoc(collection(customer(), 'orders/o1/messages'), msg('u1', 'customer', { text: '' })));
    await assertFails(addDoc(collection(customer(), 'orders/o1/messages'), msg('u1', 'customer', { text: 'x'.repeat(501) })));
    await assertFails(addDoc(collection(customer(), 'orders/o1/messages'), msg('u1', 'customer', { createdAt: new Date() })));
    await assertFails(addDoc(collection(customer(), 'orders/o1/messages'), msg('u1', 'customer', { extra: 1 })));
  });
  it('messages cannot be edited, and only the shop can delete them', async () => {
    await seedOrder({ riderId: 'r1', status: 'assigned' });
    const ref = await addDoc(collection(customer(), 'orders/o1/messages'), msg('u1', 'customer'));
    await assertFails(updateDoc(doc(customer(), ref.path), { text: 'edited' }));
    await assertFails(deleteDoc(doc(customer(), ref.path)));
    await assertSucceeds(deleteDoc(doc(staff('boss'), ref.path)));
  });
});

describe('rider presence (online / offline)', () => {
  const on = (online = true) => ({ online, lastSeen: serverTimestamp() });
  it('a rider writes only their own presence; anyone can read it; customers cannot write', async () => {
    await assertSucceeds(setDoc(doc(staff('r1'), 'presence/r1'), on()));
    await assertFails(setDoc(doc(staff('r1'), 'presence/r2'), on()));
    await assertFails(setDoc(doc(customer(), 'presence/r1'), on()));
    await assertSucceeds(getDoc(doc(guest(), 'presence/r1')));
    await assertSucceeds(getDocs(query(collection(customer(), 'presence'), where('online', '==', true))));
  });
  it('presence carries no personal details and needs a real timestamp', async () => {
    await assertFails(setDoc(doc(staff('r1'), 'presence/r1'), { ...on(), name: 'Imran' }));
    await assertFails(setDoc(doc(staff('r1'), 'presence/r1'), { online: true, lastSeen: new Date() }));
    await assertFails(setDoc(doc(staff('r1'), 'presence/r1'), { online: 'yes', lastSeen: serverTimestamp() }));
    // A blocked rider cannot write presence.
    await assertFails(setDoc(doc(staff('blocked'), 'presence/blocked'), on()));
  });
  it('the shop can switch any rider offline, and remove records', async () => {
    await assertSucceeds(setDoc(doc(staff('r1'), 'presence/r1'), on()));
    await assertSucceeds(setDoc(doc(staff('boss'), 'presence/r1'), on(false)));
    await assertSucceeds(updateDoc(doc(staff('boss'), 'riders/r1'), { online: false }));
    await assertSucceeds(deleteDoc(doc(staff('boss'), 'presence/r1')));
    await assertFails(deleteDoc(doc(staff('r1'), 'presence/r1')));
  });
  it('a rider heartbeat updates only lastSeen on the rider record', async () => {
    await assertSucceeds(updateDoc(doc(staff('r1'), 'riders/r1'), { lastSeen: serverTimestamp() }));
    await assertFails(updateDoc(doc(staff('r1'), 'riders/r1'), { lastSeen: serverTimestamp(), active: true, name: 'X' }));
  });
});

describe('chat read receipts', () => {
  const at = () => ({ at: serverTimestamp() });
  it('each side writes only its own "read" time; participants can read all of them', async () => {
    await seedOrder({ riderId: 'r1', status: 'assigned' });
    await assertSucceeds(setDoc(doc(customer(), 'orders/o1/reads/customer'), at()));
    await assertSucceeds(setDoc(doc(staff('r1'), 'orders/o1/reads/rider'), at()));
    await assertSucceeds(setDoc(doc(staff('boss'), 'orders/o1/reads/admin'), at()));
    await assertFails(setDoc(doc(customer(), 'orders/o1/reads/rider'), at()));
    await assertFails(setDoc(doc(staff('r1'), 'orders/o1/reads/customer'), at()));
    await assertFails(setDoc(doc(staff('r2'), 'orders/o1/reads/rider'), at()));
    await assertFails(setDoc(doc(customer('u2', '+923111111111'), 'orders/o1/reads/customer'), at()));
    await assertSucceeds(getDocs(collection(customer(), 'orders/o1/reads')));
    await assertSucceeds(getDocs(collection(staff('r1'), 'orders/o1/reads')));
    await assertFails(getDocs(collection(staff('r2'), 'orders/o1/reads')));
  });
  it('needs a real server time and nothing else', async () => {
    await seedOrder({ riderId: 'r1', status: 'assigned' });
    await assertFails(setDoc(doc(customer(), 'orders/o1/reads/customer'), { at: new Date() }));
    await assertFails(setDoc(doc(customer(), 'orders/o1/reads/customer'), { ...at(), extra: 1 }));
  });
});

describe('customer reports', () => {
  const rep = (over = {}) => ({ orderId: 'o1', orderNumber: 'AL-1', customerId: 'u1', customerName: 'Ali', customerPhone: '+923001234567', riderId: 'r1', riderName: 'Imran', about: 'rider', reason: 'Rider behaviour', details: 'Rude', status: 'open', reply: '', createdAt: serverTimestamp(), ...over });
  it('a customer reports their own order to the shop; others cannot see it', async () => {
    await seedOrder({ riderId: 'r1' });
    const ref = await addDoc(collection(customer(), 'reports'), rep());
    await assertSucceeds(getDoc(doc(customer(), ref.path)));
    await assertSucceeds(getDoc(doc(staff('boss'), ref.path)));
    await assertFails(getDoc(doc(staff('r1'), ref.path)));
    await assertFails(getDoc(doc(customer('u2', '+923111111111'), ref.path)));
    await assertFails(addDoc(collection(customer('u2', '+923111111111'), 'reports'), rep({ customerId: 'u2' })));
    await assertFails(addDoc(collection(customer(), 'reports'), rep({ status: 'resolved' })));
    await assertFails(addDoc(collection(customer(), 'reports'), rep({ reply: 'fake' })));
    await assertFails(updateDoc(doc(customer(), ref.path), { status: 'resolved' }));
    await assertSucceeds(updateDoc(doc(staff('boss'), ref.path), { status: 'resolved', reply: 'We spoke to the rider', resolvedAt: serverTimestamp() }));
  });
  it('rider star rating: everyone signed in reads, only the shop writes', async () => {
    await assertSucceeds(setDoc(doc(staff('boss'), 'riderStats/r1'), { average: 4.6, count: 12 }));
    await assertSucceeds(getDoc(doc(customer(), 'riderStats/r1')));
    await assertFails(setDoc(doc(staff('r1'), 'riderStats/r1'), { average: 5, count: 99 }));
    await assertFails(setDoc(doc(staff('boss'), 'riderStats/r1'), { average: 9, count: 1 }));
  });
});

describe('assigning riders', () => {
  it('only an on-shift, active rider can be given an order', async () => {
    const to = (uid) => ({ status: 'assigned', riderId: uid, riderName: uid, riderPhone: '0300', history: ev('assigned', 'boss'), updatedAt: serverTimestamp() });
    await seedOrder({ status: 'confirmed' });
    await assertFails(updateDoc(doc(staff('boss'), 'orders/o1'), to('off')));
    await assertFails(updateDoc(doc(staff('boss'), 'orders/o1'), to('blocked')));
    await assertFails(updateDoc(doc(staff('boss'), 'orders/o1'), to('nobody')));
    await assertSucceeds(updateDoc(doc(staff('boss'), 'orders/o1'), to('r1')));
  });
});

describe('taking an order back', () => {
  it('the shop can take back an assigned order but not one that is on the way', async () => {
    const back = { status: 'confirmed', riderId: null, riderName: null, riderPhone: null, history: ev('confirmed', 'boss'), updatedAt: serverTimestamp() };
    await seedOrder({ status: 'assigned', riderId: 'r1', riderName: 'Imran', riderPhone: '0300' });
    await assertSucceeds(updateDoc(doc(staff('boss'), 'orders/o1'), back));
    await seedOrder({ status: 'outForDelivery', riderId: 'r1', riderName: 'Imran', riderPhone: '0300' }, 'o2');
    await assertFails(updateDoc(doc(staff('boss'), 'orders/o2'), back));
    await assertFails(updateDoc(doc(staff('boss'), 'orders/o2'), { riderId: 'r2', riderName: 'Bilal', updatedAt: serverTimestamp() }));
    // Cancelling an order that is on the way is still possible (rider stays on it).
    await assertSucceeds(updateDoc(doc(staff('boss'), 'orders/o2'), { status: 'cancelled', cancelReason: 'Customer asked', history: ev('cancelled', 'boss'), updatedAt: serverTimestamp() }));
  });
});

describe('area fees', () => {
  it('uses the area fee from settings, else the default', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'config/app'), { acceptingOrders: true, deliveryFee: 150, freeDeliveryFrom: 6000, minOrderTotal: 0, maxCylindersPerOrder: 20, areaFees: { dha: 250 } });
    });
    const dha = { label: 'Home', line1: 'Main Boulevard', area: ' DHA ', landmark: '', city: 'Lahore', lat: 31.51, lng: 74.34 };
    await assertSucceeds(setDoc(doc(customer(), 'orders/a1'), order({ address: dha, deliveryFee: 250, total: 3546 })));
    await assertFails(setDoc(doc(customer(), 'orders/a2'), order({ address: dha, deliveryFee: 150, total: 3446 })));
    await assertSucceeds(setDoc(doc(customer(), 'orders/a3'), order()));
  });
});

describe('shop operations and staff roles', () => {
  const asStaff = () => env.authenticatedContext('clerk').firestore();
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'admins/clerk'), { email: 'clerk@alphalpg.pk', role: 'staff' });
    });
  });
  const entry = { customerId: 'u1', customerName: 'Ali', kind: 'deposit', amount: 4000, empties: 0, note: '', by: 'boss', at: serverTimestamp() };
  it('ledger: admin only, validated, append-only', async () => {
    await assertSucceeds(addDoc(collection(staff('boss'), 'ledger'), entry));
    await assertFails(addDoc(collection(customer(), 'ledger'), { ...entry, by: 'u1' }));
    await assertFails(addDoc(collection(staff('boss'), 'ledger'), { ...entry, kind: 'gift' }));
    await assertFails(addDoc(collection(staff('boss'), 'ledger'), { ...entry, amount: -1 }));
    await assertFails(addDoc(collection(staff('boss'), 'ledger'), { ...entry, by: 'someone' }));
    await assertFails(getDocs(collection(customer(), 'ledger')));
  });
  it('handovers: admin writes; the rider reads only their own', async () => {
    const h = { riderId: 'r1', riderName: 'Imran', amount: 5000, note: '', by: 'boss', at: serverTimestamp() };
    const ref = await addDoc(collection(staff('boss'), 'handovers'), h);
    await assertSucceeds(getDoc(doc(staff('r1'), ref.path)));
    await assertFails(getDoc(doc(staff('r2'), ref.path)));
    await assertFails(addDoc(collection(staff('r1'), 'handovers'), { ...h, by: 'r1' }));
    await assertFails(addDoc(collection(staff('boss'), 'handovers'), { ...h, amount: 0 }));
  });
  it('audit: any admin can log, only the owner can read, nobody can change', async () => {
    const a = { by: 'clerk', byName: 'Clerk', action: 'markPaid', target: 'o1', detail: '', at: serverTimestamp() };
    const ref = await addDoc(collection(asStaff(), 'audit'), a);
    await assertFails(getDoc(doc(asStaff(), ref.path)));
    await assertSucceeds(getDoc(doc(staff('boss'), ref.path)));
    await assertFails(updateDoc(doc(staff('boss'), ref.path), { detail: 'x' }));
    await assertFails(deleteDoc(doc(staff('boss'), ref.path)));
    await assertFails(addDoc(collection(asStaff(), 'audit'), { ...a, by: 'boss' }));
  });
  it('errors: any signed-in app can report; only admins read', async () => {
    const e = { app: 'rider', version: '1.0.0+3', uid: 'u1', message: 'boom', stack: 'trace', at: serverTimestamp() };
    const ref = await addDoc(collection(customer(), 'errors'), e);
    await assertFails(getDoc(doc(customer(), ref.path)));
    await assertSucceeds(getDoc(doc(staff('boss'), ref.path)));
    await assertFails(addDoc(collection(guest(), 'errors'), e));
    await assertFails(addDoc(collection(customer(), 'errors'), { ...e, message: 'x'.repeat(600) }));
    await assertFails(addDoc(collection(customer(), 'errors'), { ...e, uid: 'someone-else' }));
  });
  it('staff cannot change settings, delete products, cancel paid orders or manage admins', async () => {
    await assertSucceeds(setDoc(doc(staff('boss'), 'config/app'), { deliveryFee: 200 }));
    await assertFails(setDoc(doc(asStaff(), 'config/app'), { deliveryFee: 1 }));
    await assertFails(updateDoc(doc(asStaff(), 'config/app'), { deliveryFee: 1 }));
    await assertSucceeds(updateDoc(doc(asStaff(), 'config/app'), { acceptingOrders: false, closedMessage: 'Back at 5' }));
    await assertSucceeds(updateDoc(doc(asStaff(), 'products/cyl-6kg'), { refillPrice: 1700 }));
    await assertFails(deleteDoc(doc(asStaff(), 'products/cyl-6kg')));
    await assertSucceeds(deleteDoc(doc(staff('boss'), 'products/cyl-old')));
    await seedOrder({ paymentStatus: 'paid', status: 'confirmed' });
    await assertFails(updateDoc(doc(asStaff(), 'orders/o1'), { status: 'cancelled', cancelReason: 'x', history: ev('cancelled', 'clerk'), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(staff('boss'), 'orders/o1'), { status: 'cancelled', cancelReason: 'x', history: ev('cancelled', 'boss'), updatedAt: serverTimestamp() }));
    await seedOrder({ status: 'confirmed' }, 'o2');
    await assertSucceeds(updateDoc(doc(asStaff(), 'orders/o2'), { status: 'cancelled', cancelReason: 'x', history: ev('cancelled', 'clerk'), updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(asStaff(), 'admins/new'), { email: 'x', role: 'staff' }));
    await assertSucceeds(setDoc(doc(staff('boss'), 'admins/new'), { email: 'x@y.pk', name: 'New', role: 'staff' }));
    await assertFails(setDoc(doc(staff('boss'), 'admins/new2'), { email: 'x@y.pk', role: 'god' }));
  });
  it('delivery photo: only the assigned rider on their delivery; customer and admin can see it', async () => {
    await seedOrder({ riderId: 'r1', status: 'outForDelivery' });
    const p = { uid: 'r1', data: 'x'.repeat(300), createdAt: serverTimestamp() };
    const ref = await addDoc(collection(staff('r1'), 'orders/o1/proofs'), p);
    await assertSucceeds(getDoc(doc(customer(), ref.path)));
    await assertSucceeds(getDoc(doc(staff('boss'), ref.path)));
    await assertFails(getDoc(doc(customer('u2', '+923111111111'), ref.path)));
    await assertFails(addDoc(collection(staff('r2'), 'orders/o1/proofs'), { ...p, uid: 'r2' }));
    await assertFails(addDoc(collection(customer(), 'orders/o1/proofs'), { ...p, uid: 'u1' }));
    await assertFails(addDoc(collection(staff('r1'), 'orders/o1/proofs'), { ...p, data: 'tiny' }));
  });
});

describe('payment details with receipt, and blocking customers', () => {
  it('customer sends reference + amount with the receipt; bad values fail', async () => {
    await seedOrder({ paymentMethod: 'jazzCash' });
    const ok = { receiptAt: serverTimestamp(), paymentIssue: '', paymentReference: 'TX123456', paidAmount: 3446, updatedAt: serverTimestamp() };
    await assertSucceeds(updateDoc(doc(customer(), 'orders/o1'), ok));
    await assertFails(updateDoc(doc(customer(), 'orders/o1'), { ...ok, paymentReference: 'ab' }));
    await assertFails(updateDoc(doc(customer(), 'orders/o1'), { ...ok, paidAmount: -5 }));
    await assertFails(updateDoc(doc(customer(), 'orders/o1'), { ...ok, paidAmount: 9000000 }));
    await assertFails(updateDoc(doc(customer(), 'orders/o1'), { ...ok, total: 1 }));
  });
  it('a blocked customer cannot place orders; the shop can block and unblock', async () => {
    await assertFails(setDoc(doc(customer(), 'blocked/u1'), { name: 'Ali', phone: '+923001234567', reason: '', at: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(staff('boss'), 'blocked/u1'), { name: 'Ali', phone: '+923001234567', reason: 'Fake orders', at: serverTimestamp() }));
    await assertSucceeds(getDoc(doc(customer(), 'blocked/u1')));
    await assertFails(getDoc(doc(customer('u2', '+923111111111'), 'blocked/u1')));
    await assertFails(setDoc(doc(customer(), 'orders/ob1'), order()));
    await assertSucceeds(deleteDoc(doc(staff('boss'), 'blocked/u1')));
    await assertSucceeds(setDoc(doc(customer(), 'orders/ob1'), order()));
  });
});

describe('payment request and receipts', () => {
  const req = { method: 'easyPaisa', account: '03001234567', accountTitle: 'Alpha LPG', note: '', amount: 3446, sentAt: serverTimestamp() };
  const receipt = (over = {}) => ({ uid: 'u1', data: 'x'.repeat(200), note: '', createdAt: serverTimestamp(), ...over });
  it('the shop sends payment instructions; the customer cannot write them', async () => {
    await seedOrder({ paymentMethod: 'jazzCash' });
    await assertFails(updateDoc(doc(customer(), 'orders/o1'), { paymentRequest: req, updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(staff('boss'), 'orders/o1'), { paymentRequest: req, paymentIssue: '', updatedAt: serverTimestamp() }));
    const o = await getDoc(doc(customer(), 'orders/o1'));
    assert.equal(o.data().paymentRequest.account, '03001234567');
  });
  it('the customer uploads a receipt for a prepaid unpaid order, and the order is flagged', async () => {
    await seedOrder({ paymentMethod: 'jazzCash', paymentIssue: 'Receipt not clear' });
    await assertSucceeds(addDoc(collection(customer(), 'orders/o1/receipts'), receipt()));
    await assertSucceeds(updateDoc(doc(customer(), 'orders/o1'), { receiptAt: serverTimestamp(), paymentIssue: '', updatedAt: serverTimestamp() }));
    // ... but cannot touch anything else, mark it paid, or keep the issue text.
    await assertFails(updateDoc(doc(customer(), 'orders/o1'), { receiptAt: serverTimestamp(), paymentStatus: 'paid', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(customer(), 'orders/o1'), { receiptAt: serverTimestamp(), paymentIssue: 'fake', updatedAt: serverTimestamp() }));
  });
  it('receipts: only that customer and the shop can see them; size and fields are limited', async () => {
    await seedOrder({ paymentMethod: 'jazzCash' });
    const ref = await addDoc(collection(customer(), 'orders/o1/receipts'), receipt());
    await assertSucceeds(getDoc(doc(customer(), ref.path)));
    await assertSucceeds(getDoc(doc(staff('boss'), ref.path)));
    await assertFails(getDoc(doc(customer('u2', '+923111111111'), ref.path)));
    await assertFails(getDoc(doc(staff('r1'), ref.path)));
    await assertFails(addDoc(collection(customer('u2', '+923111111111'), 'orders/o1/receipts'), receipt({ uid: 'u2' })));
    await assertFails(addDoc(collection(customer(), 'orders/o1/receipts'), receipt({ data: 'x'.repeat(460000) })));
    await assertFails(addDoc(collection(customer(), 'orders/o1/receipts'), receipt({ data: 'tiny' })));
    await assertFails(addDoc(collection(customer(), 'orders/o1/receipts'), receipt({ extra: 1 })));
    await assertFails(addDoc(collection(customer(), 'orders/o1/receipts'), receipt({ createdAt: new Date() })));
    await assertFails(updateDoc(doc(customer(), ref.path), { note: 'edit' }));
    await assertSucceeds(deleteDoc(doc(staff('boss'), ref.path)));
  });
  it('no receipt upload for cash orders or paid ones', async () => {
    await seedOrder({ paymentMethod: 'cashOnDelivery' });
    await assertFails(updateDoc(doc(customer(), 'orders/o1'), { receiptAt: serverTimestamp(), paymentIssue: '', updatedAt: serverTimestamp() }));
    await seedOrder({ paymentMethod: 'jazzCash', paymentStatus: 'paid' }, 'o2');
    await assertFails(updateDoc(doc(customer(), 'orders/o2'), { receiptAt: serverTimestamp(), paymentIssue: '', updatedAt: serverTimestamp() }));
  });
});

describe('live location', () => {
  const pos = { lat: 31.51, lng: 74.34, heading: 90, speedKmh: 20, accuracy: 8, updatedAt: serverTimestamp() };
  it('the delivering rider writes, the customer reads, strangers cannot', async () => {
    await seedOrder({ riderId: 'r1', status: 'outForDelivery' });
    await assertSucceeds(setDoc(doc(staff('r1'), 'orders/o1/live/rider'), pos));
    await assertSucceeds(getDoc(doc(customer(), 'orders/o1/live/rider')));
    await assertFails(getDoc(doc(customer('u2', '+923111111111'), 'orders/o1/live/rider')));
    await assertFails(setDoc(doc(staff('r2'), 'orders/o1/live/rider'), pos));
    await assertFails(setDoc(doc(customer(), 'orders/o1/live/rider'), pos));
  });
  it('is refused before the delivery starts, after it ends, or with bad data', async () => {
    await seedOrder({ riderId: 'r1', status: 'assigned' });
    await assertFails(setDoc(doc(staff('r1'), 'orders/o1/live/rider'), pos));
    await seedOrder({ riderId: 'r1', status: 'delivered' }, 'o2');
    await assertFails(setDoc(doc(staff('r1'), 'orders/o2/live/rider'), pos));
    await seedOrder({ riderId: 'r1', status: 'outForDelivery' }, 'o3');
    await assertFails(setDoc(doc(staff('r1'), 'orders/o3/live/rider'), { ...pos, lat: 500 }));
    await assertFails(setDoc(doc(staff('r1'), 'orders/o3/live/rider'), { ...pos, extra: 1 }));
  });
});

describe('profiles, catalogue and staff', () => {
  it('customers write only their own valid profile, with their own phone', async () => {
    const ok = { name: 'Bilal Ahmed', phone: PHONE, type: 'home', businessName: '', businessType: '', email: '', createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(customer(), 'customers/u1'), ok));
    await assertFails(setDoc(doc(customer(), 'customers/u2'), ok));
    await assertFails(setDoc(doc(customer(), 'customers/u1'), { ...ok, phone: '+923111111111' }));
    await assertFails(setDoc(doc(customer(), 'customers/u1'), { ...ok, isAdmin: true }));
    await assertFails(setDoc(doc(customer(), 'customers/u1'), { ...ok, type: 'god' }));
    await assertFails(getDoc(doc(customer('u2', '+923111111111'), 'customers/u1')));
  });
  it('customers can store a notification token and delete only their own account data', async () => {
    const ok = { name: 'Bilal Ahmed', phone: PHONE, type: 'home', businessName: '', businessType: '', email: '', fcmToken: 'tok123', createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(customer(), 'customers/u1'), ok));
    await assertFails(setDoc(doc(customer(), 'customers/u1'), { ...ok, fcmToken: 'x'.repeat(400) }));
    await assertSucceeds(setDoc(doc(customer(), 'customers/u1/addresses/a1'), { label: 'Home', line1: 'x', area: 'y', createdAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(customer('u2', '+923111111111'), 'customers/u1')));
    await assertSucceeds(deleteDoc(doc(customer(), 'customers/u1/addresses/a1')));
    await assertSucceeds(deleteDoc(doc(customer(), 'customers/u1')));
  });
  it('saved locations must be inside Lahore and well formed', async () => {
    const a = { label: 'Home', line1: 'Main Blvd', area: 'Gulberg', landmark: '', city: 'Lahore', lat: 31.5, lng: 74.3, createdAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(customer(), 'customers/u1/addresses/a1'), a));
    await assertFails(setDoc(doc(customer(), 'customers/u1/addresses/a2'), { ...a, lat: 33.6, lng: 73.0 }));
    await assertFails(setDoc(doc(customer('u2'), 'customers/u1/addresses/a3'), a));
  });
  it('the catalogue is public to read, writable only by an admin', async () => {
    await assertSucceeds(getDoc(doc(guest(), 'products/cyl-6kg')));
    await assertSucceeds(getDoc(doc(guest(), 'config/app')));
    await assertFails(updateDoc(doc(customer(), 'products/cyl-6kg'), { refillPrice: 1 }));
    await assertFails(updateDoc(doc(staff('r1'), 'config/app'), { deliveryFee: 0 }));
    await assertSucceeds(updateDoc(doc(staff('boss'), 'products/cyl-6kg'), { refillPrice: 1700 }));
  });
  it('riders flip only their own online switch; only admins manage riders and admins', async () => {
    await assertSucceeds(updateDoc(doc(staff('r1'), 'riders/r1'), { online: false, lastSeen: serverTimestamp() }));
    await assertFails(updateDoc(doc(staff('r1'), 'riders/r1'), { active: false }));
    await assertFails(updateDoc(doc(staff('r1'), 'riders/r2'), { online: false }));
    await assertFails(setDoc(doc(staff('r1'), 'admins/r1'), { email: 'x' }));
    await assertFails(setDoc(doc(customer(), 'riders/u1'), { name: 'Me', phone: '1', active: true }));
    await assertSucceeds(setDoc(doc(staff('boss'), 'riders/new'), { name: 'New', phone: '+923001', active: true, online: false }));
  });
  it('guests may send a bulk quote, with limits; only admins read them all', async () => {
    const q = { customerId: '', businessName: 'Lahore Grill', contactName: 'Bilal', phone: PHONE, businessType: 'Restaurant', monthlyKg: 900, preferredSize: '45.4 KG', area: 'Gulberg', notes: '', status: 'new', createdAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(guest(), 'quoteRequests/q1'), q));
    await assertFails(setDoc(doc(guest(), 'quoteRequests/q2'), { ...q, notes: 'x'.repeat(1001) }));
    await assertFails(setDoc(doc(guest(), 'quoteRequests/q3'), { ...q, status: 'won' }));
    await assertFails(getDoc(doc(guest(), 'quoteRequests/q1')));
    await assertSucceeds(getDoc(doc(staff('boss'), 'quoteRequests/q1')));
  });
});
