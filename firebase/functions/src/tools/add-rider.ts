// Creates a rider: a sign-in (email + password) and the riders/{uid} record.
// Run on the owner's computer with a service account key:
//   GOOGLE_APPLICATION_CREDENTIALS=key.json npm run add-rider -- imran@alphalpg.pk "Imran Khan" +923001234567 "Temp#Pass1"
// To block a rider later set `active` to false in the console (riders/{uid}).
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();

async function main() {
  const [email, name, phone, password] = process.argv.slice(2);
  if (!email || !name || !phone || !password) {
    console.error('Usage: npm run add-rider -- <email> "<Full name>" <+92 phone> <password>');
    process.exit(1);
  }
  if (password.length < 8) {
    console.error("Password must be at least 8 characters.");
    process.exit(1);
  }
  const auth = getAuth();
  let uid: string;
  try {
    uid = (await auth.getUserByEmail(email)).uid;
    await auth.updateUser(uid, { password, displayName: name });
    console.log(`Updated existing sign-in for ${email}`);
  } catch {
    uid = (await auth.createUser({ email, password, displayName: name })).uid;
    console.log(`Created sign-in for ${email}`);
  }
  await getFirestore().doc(`riders/${uid}`).set(
    { name, phone, vehicle: "Motorbike", active: true, online: false },
    { merge: true },
  );
  console.log(`Rider ready: ${name} (${uid}). Give them the email and password; they can change it with "Forgot password".`);
}
main();
