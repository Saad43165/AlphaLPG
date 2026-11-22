import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger, setGlobalOptions } from "firebase-functions/v2";
import { formatOrderNumber, ItemIn, priceOrder, Product, Settings } from "./pricing";

initializeApp();
setGlobalOptions({ region: "asia-south1" }); // Mumbai — closest to Lahore
const db = getFirestore();

const DEFAULT_SETTINGS: Settings = {
  deliveryFee: 150,
  freeDeliveryFrom: 6000,
  maxCylindersPerOrder: 20,
};

/**
 * Runs for every new order:
 *  1. Re-prices it from the live catalogue (the client total is never trusted).
 *  2. Assigns a sequential, human-friendly order number (AL-000123).
 * If an item is unavailable the order is cancelled with a reason the
 * customer sees in the app.
 */
export const onOrderCreated = onDocumentCreated("orders/{orderId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const order = snap.data();

  const [productsSnap, settingsSnap] = await Promise.all([
    db.collection("products").get(),
    db.doc("config/app").get(),
  ]);
  const products = new Map<string, Product>(
    productsSnap.docs.map((d) => [d.id, { id: d.id, ...(d.data() as Omit<Product, "id">) }]),
  );
  const settings: Settings = { ...DEFAULT_SETTINGS, ...(settingsSnap.data() ?? {}) } as Settings;

  let priced;
  try {
    priced = priceOrder((order.items ?? []) as ItemIn[], products, settings);
  } catch (e) {
    logger.warn("Order rejected", { orderId: snap.id, error: String(e) });
    await snap.ref.update({
      status: "cancelled",
      cancelReason: `Could not accept order: ${(e as Error).message}`,
      history: FieldValue.arrayUnion({
        status: "cancelled", at: new Date(), by: "system", note: String(e),
      }),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return;
  }

  const counter = db.doc("counters/orders");
  const number = await db.runTransaction(async (tx) => {
    const c = await tx.get(counter);
    const next = ((c.data()?.value as number | undefined) ?? 0) + 1;
    tx.set(counter, { value: next }, { merge: true });
    return next;
  });

  // Coupons and points were already checked by the security rules; keep them.
  const discount = typeof order.discount === "number" ? order.discount : 0;
  const total = Math.max(0, priced.total - discount);
  const priceChanged = total !== order.total;
  if (priceChanged) {
    logger.info("Order re-priced", { orderId: snap.id, client: order.total, server: total });
  }
  await snap.ref.update({
    ...priced,
    total,
    orderNumber: formatOrderNumber(number),
    pricingVerified: true,
    priceChanged,
    updatedAt: FieldValue.serverTimestamp(),
  });
});
