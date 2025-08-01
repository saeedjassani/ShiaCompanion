const admin = require('firebase-admin');
const fs = require('fs');
const csv = require('csv-parser');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const collectionName = 'zikr';

let successCount = 0;
let failureCount = 0;
let skippedCount = 0;

const uploadPromises = [];

fs.createReadStream('zikr.csv')
  .pipe(csv())
  .on('data', (row) => {
    uploadPromises.push(
      (async () => {
        if (row['\ufeffU_ID']) {
          row['U_ID'] = row['\ufeffU_ID'];
          delete row['\ufeffU_ID'];
        }

        const docId = row['U_ID']?.trim();
        if (!docId || docId.toLowerCase() === 'null') {
          console.warn(`⏭️ Skipping row with missing or invalid U_ID: ${JSON.stringify(row)}`);
          skippedCount++;
          return;
        }

        const duaData = {
          title: row['Title'] || '',
          data: row['Data'] === 'NULL' ? '' : row['Data'] || '',
          code: row['Code'] || '',
        };

        try {
          await db.collection(collectionName).doc(docId).set(duaData);
          console.log(`✅ Uploaded dua: ${docId}`);
          successCount++;
        } catch (error) {
          console.error(`❌ Failed uploading dua ${docId}:`, error.message);
          failureCount++;
        }
      })()
    );
  })
  .on('end', async () => {
    await Promise.all(uploadPromises);  // Wait for all uploads to finish
    console.log('\n✅ CSV upload complete.');
    console.log(`✔️ Success: ${successCount}`);
    console.log(`❌ Failures: ${failureCount}`);
    console.log(`⏭️ Skipped: ${skippedCount}`);
  });
