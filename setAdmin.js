const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const uid = "xCzEwc2NHJahDrJ0sq0E8ALKffO2";

admin.auth().setCustomUserClaims(uid, { admin: true })
  .then(() => {
    console.log("Custom claim set for admin!");
  })
  .catch(err => {``
    console.error(err);
  });
