const admin = require('firebase-admin');
const axios = require('axios');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const toArabicDigits = (num) => String(num).replace(/\d/g, d => "٠١٢٣٤٥٦٧٨٩"[d]);

// Same logic as your Flutter code to identify Arabic lines
function isArabic(s) {
    if (!s) return false;
    for (let i = 0; i < s.length && i < 35; i++) {
        let c = s.charCodeAt(i);
        if (c >= 0x0600 && c <= 0x06FF) return true;
    }
    return false;
}

async function surgicalScriptSwap() {
    const INDOPAK_BISMILLAH = "بِسۡمِ اللهِ الرَّحۡمٰنِ الرَّحِيۡمِ";

    // for (let s = 1; s <= 114; s++) {
    const s = 1; // For testing, just do Surah 1 (Fatiha)
    const docId = `A${s + 4}`;
    const docRef = db.collection('zikr').doc(docId);

    try {
        const doc = await docRef.get();

        const { data } = doc.data();
        const lines = data.split('\n');

        // 1. Fetch Indo-Pak verses for this Surah
        const response = await axios.get(`https://api.quran.com/api/v4/quran/verses/indopak`, {
            params: { chapter_number: s, per_page: 300 }
        });
        const apiVerses = response.data.verses;

        let versePointer = 0;
        let foundHeaderBismillah = false;

        // 2. Iterate through your existing lines and swap ONLY the Arabic ones
        const updatedLines = lines.map((line) => {
            const trimmed = line.trim();

            if (isArabic(trimmed)) {
                // Handle the unnumbered Bismillah header (Surahs 2-114)
                if (s !== 1 && !foundHeaderBismillah) {
                    foundHeaderBismillah = true;
                    return INDOPAK_BISMILLAH;
                }

                // Replace with API verse + Ayah symbol
                if (versePointer < apiVerses.length) {
                    const v = apiVerses[versePointer];
                    versePointer++;

                    // For Fatiha (s=1), Verse 1 IS the Bismillah, so we don't usually add the number 1 
                    // but for all other verses, we append the circle and the number
                    const verseText = v.text_indopak;
                    const ayahMarker = ` (${v.verse_key.split(':')[1]})`;

                    return (s === 1 && v.verse_number === 1) ? verseText : `${verseText}${ayahMarker}`;
                }
            }

            // If not Arabic (it's Transliteration, Translation, or Description), keep it as is
            return line;
        });

        console.log(updatedLines.join('\n'));
        // 3. Update Firestore with the rebuilt string
        //   await docRef.update({ data: updatedLines.join('\n') });
        console.log(`✅ Swapped Arabic for ${docId} (Surah ${s}) - Preserved Transliteration`);

    } catch (error) {
        console.error(`❌ Error at ${docId}:`, error.message);

    }
}

surgicalScriptSwap();