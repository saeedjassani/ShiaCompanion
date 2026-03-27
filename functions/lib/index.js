"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildZikrIndex = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
// Rebuilds zikr index whenever a zikr document changes
exports.buildZikrIndex = functions.firestore
    .onDocumentWritten("zikr/{docId}", async (event) => {
    try {
        const snapshot = await db.collection("zikr").get();
        const index = {};
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
    }
    catch (error) {
        console.error("Error building index:", error);
        throw error;
    }
});
//# sourceMappingURL=index.js.map