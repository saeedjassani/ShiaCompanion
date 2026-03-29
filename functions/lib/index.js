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
function slugifyTitle(title) {
    return title
        .toLowerCase()
        .replace(/[^\w\s-]/g, " ")
        .replace(/[_\s]+/g, "-")
        .replace(/-+/g, "-")
        .replace(/^-|-$/g, "");
}
function normalizeSlugAliases(values, exclude) {
    if (!Array.isArray(values))
        return [];
    const normalizedExclude = slugifyTitle(exclude ?? "");
    const seen = new Set();
    return values
        .map((value) => slugifyTitle(value?.toString() ?? ""))
        .filter((alias) => {
        if (!alias || alias === normalizedExclude || seen.has(alias)) {
            return false;
        }
        seen.add(alias);
        return true;
    });
}
// Rebuilds zikr index whenever a zikr document changes
exports.buildZikrIndex = functions.firestore
    .onDocumentWritten("zikr/{docId}", async (event) => {
    try {
        const snapshot = await db.collection("zikr").get();
        const index = {};
        const slugLookup = {};
        const sortedDocs = [...snapshot.docs].sort((a, b) => a.id.localeCompare(b.id));
        sortedDocs.forEach((doc) => {
            const data = doc.data();
            if (data.title) {
                const hasPrimaryData = data.data && data.data.toString().trim();
                const hasTabData = Array.isArray(data.tabs) &&
                    data.tabs.some((tab) => tab && tab.toString().trim());
                const slug = slugifyTitle(data.slug?.toString() ?? "");
                const slugAliases = normalizeSlugAliases(data.slugAliases, slug);
                const item = {
                    title: data.title,
                    hasData: !!hasPrimaryData || !!hasTabData || doc.id.includes("~") || doc.id.includes("|"),
                };
                if (slug) {
                    item.slug = slug;
                    if (slugLookup[slug] && slugLookup[slug] !== doc.id) {
                        console.warn(`Duplicate slug "${slug}" for ${doc.id}; keeping ${slugLookup[slug]}`);
                    }
                    else {
                        slugLookup[slug] = doc.id;
                    }
                }
                if (slugAliases.length > 0) {
                    item.slugAliases = slugAliases;
                    slugAliases.forEach((alias) => {
                        if (slugLookup[alias] && slugLookup[alias] !== doc.id) {
                            console.warn(`Duplicate slug alias "${alias}" for ${doc.id}; keeping ${slugLookup[alias]}`);
                            return;
                        }
                        slugLookup[alias] = doc.id;
                    });
                }
                if (typeof data.order === "number") {
                    item.order = data.order;
                }
                index[doc.id] = item;
            }
        });
        // Write single index doc
        await db.doc("zikr_meta/index").set({
            items: index,
            slugLookup,
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