# Alpha LPG: suggestions and plans

## Polishing still to do
1. Dark-mode and big-font pass over every screen in all three apps.
2. Empty and loading states, and clear retry messages on important actions
   (place order, send receipt, mark delivered).
3. Rider battery-saving guide (done: Me tab, plus a one-time tip).
4. Small details: same wording, button sizes and icons in all three apps.
5. Urdu translation (customers and riders expect it).

## Safety and trust
- Phone verification (OTP) for new customers: needs an SMS service and a small
  server; see "OTP options" below.
- Until then: call every new customer once before the first delivery (the admin
  app now shows a "New customer: call to confirm" tag and a Call button), use
  the Block button, and the payment checks.

## OTP options
- Pakistani SMS company (cheapest, needs an account and an API key; some ask for a
  registered sender name).
- Twilio Verify (easy and reliable; needs a card; check the price per SMS to
  Pakistan).
- WhatsApp codes through a WhatsApp Business provider.
- Free manual check: customer sends a code on WhatsApp, or the shop calls.
- A small server (free Cloudflare Worker) sends and checks the code and logs the
  customer in; the app and database rules stay as they are.
- Never put the API key in the app or in the repository: set it as a secret in
  the server's settings.

## Before launch
- Host the privacy policy and delete-account pages (see PLAY_STORE.md).
- Play Store internal test with your own riders first.
- Keep the signing keys backed up in two places.

## Weekly routine
- Admin app > More: check App errors, Customer reports, Cash handover and rider ratings.
- Watch the Firebase usage graph for a week (free-plan limits).
