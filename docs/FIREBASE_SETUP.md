# Firebase setup (project: smarttasksmanager)

Both apps use Firebase Authentication (customer: Phone OTP, rider: Email/Password) and Cloud Firestore.

## 1. Register the Android apps (Firebase console, works on a phone)
Project settings → Your apps → Add app → Android:
- Customer: package `pk.alphalpg.customer`
- Rider: package `pk.alphalpg.rider`
Add the SHA-1 and SHA-256 of the signing key used for the APK (phone sign-in fails without them).
Get them with `cd apps/customer_app/android && ./gradlew signingReport`.

Or from a computer / Google Cloud Shell:
```bash
npx firebase-tools login
npx firebase-tools apps:create ANDROID "Alpha LPG" --package-name pk.alphalpg.customer --project smarttasksmanager
npx firebase-tools apps:create ANDROID "Alpha LPG Rider" --package-name pk.alphalpg.rider --project smarttasksmanager
cd apps/customer_app && flutterfire configure --project=smarttasksmanager --android-package-name=pk.alphalpg.customer
cd ../rider_app && flutterfire configure --project=smarttasksmanager --android-package-name=pk.alphalpg.rider
```
This overwrites `lib/firebase_options.dart` in each app.

## 2. Authentication
- Sign-in method → enable **Phone** (customer) and **Email/Password** (rider).
- Settings → SMS region policy → allow Pakistan (+92).
- Optional: add test phone numbers while developing.

## 3. Firestore
Create the database (region `asia-south1`), then deploy rules and indexes:
```bash
cd firebase && npx firebase-tools deploy --only firestore --project smarttasksmanager
```
WARNING: this replaces any rules already in smarttasksmanager. If that project serves another app, use a separate project or merge the rules first.

## 4. Seed data and staff
```bash
cd firebase/functions
GOOGLE_APPLICATION_CREDENTIALS=key.json npm run seed
GOOGLE_APPLICATION_CREDENTIALS=key.json npm run add-admin -- owner@alphalpg.pk
GOOGLE_APPLICATION_CREDENTIALS=key.json npm run add-rider -- imran@alphalpg.pk "Imran Khan" +923001234567 "Temp#Pass1"
```
Orders are rejected until `products` and `config/app` exist.

## 5. Test the rules
```bash
cd firebase && npx firebase-tools emulators:exec --only firestore --project demo-alpha "cd functions && node --test test/rules.test.mjs"
```
