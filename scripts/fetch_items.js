const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

async function main() {
  // This script assumes you have a serviceAccountKey.json file or 
  // FIREBASE_SERVICE_ACCOUNT_KEY environment variable pointing to it.
  const credPath = process.env.FIREBASE_SERVICE_ACCOUNT_KEY || path.join(__dirname, 'serviceAccountKey.json');
  
  if (!fs.existsSync(credPath)) {
    console.error(`Error: Service account key not found at ${credPath}`);
    console.log("Please provide a valid serviceAccountKey.json or set FIREBASE_SERVICE_ACCOUNT_KEY.");
    process.exit(1);
  }

  // Initialize Firebase
  const serviceAccount = require(path.resolve(credPath));
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });

  const db = admin.firestore();
  
  console.log("Fetching documents from 'zikr' collection...");
  const snapshot = await db.collection('zikr').get();
  
  // Store all docs in a Map for easy lookup
  const allDocs = new Map();
  snapshot.forEach(doc => {
    allDocs.set(doc.id, doc.data());
  });

  const fetchedItems = {};
  
  console.log(`Processing ${allDocs.size} documents...`);

  for (const [key, value] of allDocs) {
    // Logic mirrors _loadItemsFromFirebase in lib/pages/home_page.dart
    
    const dataContent = value.data;
    // Dart: value['data'].toString().isNotEmpty
    const hasData = dataContent !== null && dataContent !== undefined;
    
    const isCategory = key.includes('~');
    const isAlias = key.includes('|');

    if (!(hasData || isCategory || isAlias)) {
      continue;
    }

    if (isAlias) {
      const parts = key.split('|');
      if (parts.length > 1) {
        const originalKey = parts[1];
        const originalDoc = allDocs.get(originalKey);
        
        // If original doc exists but has no data, skip the alias
        if (originalDoc) {
          const origData = originalDoc.data;
          if (origData === null || origData === undefined || String(origData) === '') {
            continue;
          }
        }
      }
    }
    
    const title = value.title;
    if (!title) {
      continue;
    }

    fetchedItems[key] = title;
  }

  // Sort keys for consistent output
  const sortedKeys = Object.keys(fetchedItems).sort();
  const sortedItems = {};
  sortedKeys.forEach(key => sortedItems[key] = fetchedItems[key]);
  
  const outputPath = path.join(__dirname, '../assets/zikr.json');
  fs.writeFileSync(outputPath, JSON.stringify(sortedItems, null, 2), 'utf8');
  console.log(`Successfully wrote ${Object.keys(sortedItems).length} items to ${outputPath}`);
}

main().catch(console.error);