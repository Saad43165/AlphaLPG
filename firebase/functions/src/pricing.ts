// Server-side mirror of packages/alpha_core/lib/src/pricing.dart.
// Keep the two in sync.

export interface Product {
  id: string;
  name: string;
  sizeKg: number;
  refillPrice: number;
  newCylinderPrice?: number | null;
  active?: boolean;
  inStock?: boolean;
}

export interface Settings {
  deliveryFee: number;
  freeDeliveryFrom: number;
  maxCylindersPerOrder: number;
}

export interface ItemIn {
  productId: string;
  type: "refill" | "newCylinder";
  quantity: number;
}

export interface PricedItem extends ItemIn {
  name: string;
  sizeKg: number;
  unitPrice: number;
}

export interface Priced {
  items: PricedItem[];
  subtotal: number;
  deliveryFee: number;
  total: number;
  cylinderCount: number;
  emptiesToCollect: number;
}

export function priceOrder(
  items: ItemIn[],
  products: Map<string, Product>,
  settings: Settings,
): Priced {
  const priced: PricedItem[] = [];
  for (const i of items) {
    const p = products.get(i.productId);
    if (!p || p.active === false || p.inStock === false) {
      throw new Error(`Product ${i.productId} is not available`);
    }
    const qty = Math.trunc(i.quantity);
    if (!(qty >= 1 && qty <= 99)) throw new Error("Invalid quantity");
    const unitPrice =
      i.type === "newCylinder" && p.newCylinderPrice != null
        ? p.newCylinderPrice
        : p.refillPrice;
    priced.push({
      productId: p.id,
      name: p.name,
      sizeKg: p.sizeKg,
      type: i.type === "newCylinder" ? "newCylinder" : "refill",
      unitPrice,
      quantity: qty,
    });
  }
  const subtotal = priced.reduce((s, i) => s + i.unitPrice * i.quantity, 0);
  const cylinderCount = priced.reduce((n, i) => n + i.quantity, 0);
  if (cylinderCount > settings.maxCylindersPerOrder) {
    throw new Error("Too many cylinders for one order");
  }
  const free =
    subtotal === 0 ||
    (settings.freeDeliveryFrom > 0 && subtotal >= settings.freeDeliveryFrom);
  const deliveryFee = free ? 0 : settings.deliveryFee;
  return {
    items: priced,
    subtotal,
    deliveryFee,
    total: subtotal + deliveryFee,
    cylinderCount,
    emptiesToCollect: priced
      .filter((i) => i.type === "refill")
      .reduce((n, i) => n + i.quantity, 0),
  };
}

/** 123 → "AL-000123" */
export function formatOrderNumber(n: number): string {
  return `AL-${String(n).padStart(6, "0")}`;
}
