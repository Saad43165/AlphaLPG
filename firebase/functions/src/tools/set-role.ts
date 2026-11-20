// Grants a role to a user by phone number.
// Usage: GOOGLE_APPLICATION_CREDENTIALS=key.json npm run set-role -- +923001234567 admin|rider|none
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();

async function main() {
  const [phone, role] = process.argv.slice(2);
  if (!phone || !["admin", "rider", "none"].includes(role)) {
    console.error("Usage: npm run set-role -- <+92 phone> <admin|rider|none>");
    process.exit(1);
  }
  const user = await getAuth().getUserByPhoneNumber(phone);
  await getAuth().setCustomUserClaims(user.uid, role === "none" ? {} : { [role]: true });
  if (role === "rider") {
    await getFirestore().doc(`riders/${user.uid}`).set({ phone, active: true }, { merge: true });
  }
  console.log(`${phone} (${user.uid}) is now: ${role}. They must sign out and in again.`);
}
main();
