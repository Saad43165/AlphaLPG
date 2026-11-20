# Alpha LPG: ordering & delivery apps

Mobile ordering and delivery platform for **Alpha LPG**, Lahore
(Shop # 1, Service Road, opposite Dolmen Mall · 0308 5745740 · info@alphalpg.pk).

Customers order LPG cylinders for doorstep delivery, track the order live,
and businesses request bulk supply. The project is laid out so a **rider app**
and an **admin app** can share the same data model and backend.

| Part | Path | Status |
|---|---|---|
| Customer app (Flutter, Android/iOS/web) | `apps/customer_app` | ✅ v1 |
| Shared models, pricing, repositories | `packages/alpha_core` | ✅ |
| Firebase rules, indexes, Cloud Functions | `firebase/` | ✅ |
| Rider app | `apps/rider_app` | planned, reuses `alpha_core` (`watchRiderOrders`, `updateStatus`) |
| Admin dashboard | `apps/admin_app` | planned, reuses `alpha_core` (`watchByStatus`, `assignRider`, `saveProduct`, `saveSettings`) |

## Customer app features

- **Catalogue**: the four alphalpg.pk cylinders (6 kg Rs 1,676 · 10 kg composite
  Rs 2,793 · 11.8 kg Rs 3,296 · 45.4 kg Rs 12,682). Prices come live from
  Firestore, so the owner changes them without an app update.
- **Phone-number sign-in** (SMS OTP). You can browse without signing in;
  sign-in is only asked for at checkout.
- **Home or business** profile.
- **Saved addresses** with Lahore area shortcuts and an optional GPS pin for the rider.
- **Cart**: refill pricing with an empty-cylinder exchange reminder, a free-delivery
  threshold, and minimum/maximum order rules. All rules are configurable.
- **Checkout**:
  - Deliver now, or schedule a day and time slot.
  - Cash on delivery or bank transfer. JazzCash/Easypaisa are modelled, coming next.
  - Notes for the rider.
- **Live order tracking**:
  - A timeline from Placed → Confirmed → Rider assigned → Out for delivery → Delivered.
  - The rider's name, with a call button.
  - Cancel the order while it's still unconfirmed.
  - Reorder in one tap.
  - WhatsApp help, with the order number filled in.
- **Bulk / commercial quote** form for restaurants, hotels and factories.
- **LPG safety guide**, with one-tap Rescue 1122.
- **Demo mode**: when Firebase isn't configured, the app runs on an in-memory
  backend. In demo mode:
  - Sign-in accepts any number with OTP `123456`.
  - Orders advance by themselves, so the whole journey can be shown to the owner.

## Research summary (Nov 2026)

- Alpha LPG sells 6 kg, 10 kg composite, 11.8 kg and 45.4 kg cylinders to homes
  and businesses across Lahore. Today it takes orders by WhatsApp from alphalpg.pk.
- Competitors already offer digital ordering:
  - PSO: web form, about 4 working days, Rs 1,430 delivery fee.
  - Parco Pearl Gas: e-shop and app.
  - SNGPL: app and WhatsApp, but its home delivery service was widely reported
    as unreliable.
- Lahore LPG prices are volatile, ranging from Rs 450 to Rs 570 per kg during 2026.
  So prices, fees and an "ordering paused" switch are all remote-configurable
  (`config/app`).
- Customers in this market expect cash on delivery, WhatsApp support,
  same-day delivery and visible safety assurances. Restaurants need recurring
  45.4 kg supply. The design follows patterns from local delivery apps such as
  Foodpanda and Careem:
  - "Deliver to" at the top of the screen.
  - Quantity steppers right on the product cards.
  - A sticky cart bar.
  - Live status tracking.

## Run it

```bash
cd apps/customer_app
flutter pub get
flutter run --dart-define=DEMO=true        # demo mode, no Firebase needed
flutter build apk --release --split-per-abi
```

Tests:

```bash
(cd packages/alpha_core && flutter test)   # pricing + repositories (Firestore & memory)
(cd apps/customer_app && flutter test)     # end-to-end order flow widget tests
(cd firebase/functions && npm test)        # server-side pricing
```

## Connect Firebase (production)

1. Create a Firebase project.
   - Enable **Authentication → Phone**.
   - Enable **Firestore** (region `asia-south1`).
   - Add the Android package name `pk.alphalpg.customer` and its SHA-1/SHA-256.
     Phone auth needs these.
2. Generate the app config:
   ```bash
   cd apps/customer_app
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<project-id>   # overwrites lib/firebase_options.dart
   ```
3. Deploy the rules, indexes and functions:
   ```bash
   cd firebase && firebase use <project-id>
   (cd functions && npm install)
   firebase deploy --only firestore,functions
   ```
4. Seed the catalogue and make the owner an admin:
   ```bash
   cd firebase/functions
   GOOGLE_APPLICATION_CREDENTIALS=key.json npm run seed
   GOOGLE_APPLICATION_CREDENTIALS=key.json npm run set-role -- +923085745740 admin
   ```

`onOrderCreated` re-prices every new order from the live catalogue, so a
client-side total is never trusted. It also assigns a sequential order number (`AL-000123`).

### Data model (Firestore)

- `products/{id}`: name, sizeKg, refillPrice, newCylinderPrice, badge,
  segment (home/business), active, inStock, sortOrder
- `config/app`:
  - Ordering: deliveryFee, freeDeliveryFrom, minOrderTotal, maxCylindersPerOrder,
    acceptingOrders, closedMessage
  - Shop details: phone, whatsapp, email, shopAddress, openingHours,
    serviceAreas, bankDetails
- `customers/{uid}` (name, phone, type, businessName, email) with
  `customers/{uid}/addresses/{id}`
- `orders/{id}`:
  - Customer: customer snapshot, address snapshot, notes
  - Items and money: items, subtotal, deliveryFee, total, paymentMethod/Status
  - Progress: status, history[], scheduledFor
  - Rider: riderId/Name/Phone
- `quoteRequests/{id}`: bulk enquiries
- `riders/{uid}`, `counters/orders`

Roles are Firebase Auth custom claims (`admin`, `rider`), enforced in
`firebase/firestore.rules`.

## Release signing

The test APK is signed with the debug key. Before publishing on Play Store:
- Create an upload keystore.
- Add `android/key.properties`.
- Switch `signingConfig` in `android/app/build.gradle.kts`.

See https://docs.flutter.dev/deployment/android.

## Next steps

1. **Rider app**:
   - Assigned jobs with map navigation.
   - Mark out for delivery and delivered, with OTP or photo proof.
   - Record cash collected and empty cylinders returned.
2. **Admin dashboard**:
   - Live order board; assign riders.
   - Edit prices and settings.
   - Quote CRM, daily sales, cylinder stock and empties.
3. **Push notifications** (FCM) on every status change.
4. **Payments**: JazzCash and Easypaisa.
5. **Urdu translation**: the strings are centralised, ready for `intl`.
6. **Map pin picker** (Google Maps) and delivery-zone checks.
