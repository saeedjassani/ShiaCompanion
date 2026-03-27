import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// Rebuilds zikr index whenever a zikr document changes
export const buildZikrIndex = functions.firestore
  .onDocumentWritten("zikr/{docId}", async (event) => {
    try {
      const snapshot = await db.collection("zikr").get();
      const index: { [key: string]: { title: string; hasData: boolean } } = {};

      snapshot.docs.forEach((doc) => {
        const data = doc.data();
        if (data.title) {
          const hasData = data.data && data.data.toString().trim();
          index[doc.id] = {
            title: data.title,
            hasData: !!hasData
          };
        }
      });

      // Write single index doc
      await db.doc("zikr_meta/index").set({
        items: index,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        itemCount: Object.keys(index).length,
      });

      console.log(`Index rebuilt: ${Object.keys(index).length} items`);
    } catch (error) {
      console.error("Error building index:", error);
      throw error;
    }
  });
