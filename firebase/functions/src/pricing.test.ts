import { test } from "node:test";
import assert from "node:assert/strict";
import { formatOrderNumber, priceOrder, Product } from "./pricing";

const products = new Map<string, Product>([
  ["cyl-6kg", { id: "cyl-6kg", name: "6kg Gas Cylinder", sizeKg: 6, refillPrice: 1676 }],
  ["cyl-11-8kg", { id: "cyl-11-8kg", name: "11.8kg Gas Cylinder", sizeKg: 11.8, refillPrice: 3296 }],
]);
const settings = { deliveryFee: 150, freeDeliveryFrom: 6000, maxCylindersPerOrder: 20 };

test("matches the app's pricing rules", () => {
  const one = priceOrder([{ productId: "cyl-11-8kg", type: "refill", quantity: 1 }], products, settings);
  assert.equal(one.total, 3446);
  const two = priceOrder([{ productId: "cyl-11-8kg", type: "refill", quantity: 2 }], products, settings);
  assert.equal(two.deliveryFee, 0);
  assert.equal(two.total, 6592);
  assert.equal(two.emptiesToCollect, 2);
});

test("ignores client prices and rejects unknown products", () => {
  assert.throws(() => priceOrder([{ productId: "nope", type: "refill", quantity: 1 }], products, settings));
  assert.throws(() => priceOrder([{ productId: "cyl-6kg", type: "refill", quantity: 0 }], products, settings));
});

test("order numbers", () => {
  assert.equal(formatOrderNumber(42), "AL-000042");
});
