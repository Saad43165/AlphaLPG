// Seeds products + settings from the alphalpg.pk catalogue (Nov 2026).
// Usage: GOOGLE_APPLICATION_CREDENTIALS=key.json npm run seed
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();
const db = getFirestore();

const products = [
  { id: "cyl-6kg", name: "6kg Gas Cylinder", sizeKg: 6, refillPrice: 1676, segment: "home", sortOrder: 1,
    description: "Compact cylinder for small kitchens, hostels and camping stoves.", imageAsset: "assets/products/6kg.png" },
  { id: "cyl-10kg-composite", name: "10kg Composite Cylinder", sizeKg: 10, refillPrice: 2793, segment: "home", sortOrder: 2, badge: "Lightweight",
    description: "Lightweight, rust-free composite cylinder with a see-through gas level strip.", imageAsset: "assets/products/10kg.png" },
  { id: "cyl-11-8kg", name: "11.8kg Gas Cylinder", sizeKg: 11.8, refillPrice: 3296, segment: "home", sortOrder: 3, badge: "Most popular",
    description: "The standard domestic cylinder for everyday home cooking.", imageAsset: "assets/products/11_8kg.png" },
  { id: "cyl-45-4kg", name: "45.4kg Gas Cylinder", sizeKg: 45.4, refillPrice: 12682, segment: "business", sortOrder: 4, badge: "Commercial",
    description: "Commercial cylinder for restaurants, hotels, bakeries and industry.", imageAsset: "assets/products/45_4kg.png" },
];

async function main() {
  const batch = db.batch();
  for (const { id, ...p } of products) {
    batch.set(db.collection("products").doc(id), { newCylinderPrice: null, active: true, inStock: true, imageUrl: "", ...p });
  }
  batch.set(db.doc("config/app"), {
    acceptingOrders: true,
    closedMessage: "",
    deliveryFee: 150,
    freeDeliveryFrom: 6000,
    minOrderTotal: 0,
    maxCylindersPerOrder: 20,
    phone: "03085745740",
    whatsapp: "923085745740",
    email: "info@alphalpg.pk",
    shopAddress: "Shop # 1, Service Road, Opposite Dolmen Mall, Lahore",
    openingHours: "9:00 am – 9:00 pm, every day",
    serviceAreas: ["Cantt", "Clifton Colony", "DHA", "Garden Town", "Gulberg", "Johar Town",
      "Model Town", "Cavalry Ground", "Askari", "Faisal Town", "Bahria Town", "Wapda Town"],
    bankDetails: "",
  }, { merge: true });
  await batch.commit();
  console.log(`Seeded ${products.length} products and config/app`);
}
main();
