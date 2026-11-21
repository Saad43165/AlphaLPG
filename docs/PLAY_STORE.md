# Publishing the Alpha LPG apps

## 1. Signing keys (do this first, keep them safe)

Each app has its own signing key (`alpha-customer.jks`, `alpha-rider.jks`,
`alpha-admin.jks`) and a `key.properties` file with its password. They live in
`apps/<app>/android/` and are **not** in git.

* **Back them up** (cloud drive + a USB stick). If you lose a key you can never
  update that app on Google Play again.
* Never share them or post them anywhere.
* Phones that have a *test* APK (signed with the old debug key) must uninstall
  it once before installing a release-signed APK.

## 2. Host the privacy policy (free)

Google Play needs a web address for the privacy policy and for "delete my
account". Two files are ready: `docs/privacy-policy.html` and
`docs/delete-account.html`.

Easiest (GitHub Pages):
1. GitHub repo → Settings → Pages → Source: *Deploy from a branch*, branch
   `main`, folder `/docs`.
2. After a minute the pages are at
   `https://<your-github-name>.github.io/AlphaLPG/privacy-policy.html` and
   `.../delete-account.html`.
3. Paste those links in Play Console → App content.

## 3. Build

```bash
cd apps/customer_app
flutter build appbundle --release --dart-define-from-file=config/keys.json --dart-define=PRODUCTION=true
```
(`appbundle` for the Play Store, `apk` for sending to people directly.)

## 4. Play Console checklist

* Google Play developer account ($25 once).
* App name, short and long description, icon, 2+ phone screenshots, feature graphic.
* Privacy policy URL and account-deletion URL (above).
* Data safety form: name, phone, address/location, order history, photos
  (receipts, delivery photos), messages, crash logs. Data is encrypted in
  transit; users can request deletion.
* Content rating questionnaire, target audience 18+.
* Upload the `.aab` to Internal testing first, add your testers, then promote.
