// Marks an existing sign-in as an owner/admin (creates admins/{uid}).
//   GOOGLE_APPLICATION_CREDENTIALS=key.json npm run add-admin -- owner@alphalpg.pk
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();

async function main() {
  const [email] = process.argv.slice(2);
  if (!email) {
    console.error("Usage: npm run add-admin -- <email>");
    process.exit(1);
  }
  const user = await getAuth().getUserByEmail(email);
  await getFirestore().doc(`admins/${user.uid}`).set({ email, createdAt: new Date() });
  console.log(`${email} (${user.uid}) is now an admin.`);
}
main();
