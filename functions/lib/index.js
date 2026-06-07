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
function normalizeSlug(value) {
    return `${value ?? ""}`
        .toLowerCase()
        .replace(/[^\w\s-]/g, " ")
        .replace(/[_\s]+/g, "-")
        .replace(/-+/g, "-")
        .replace(/^-|-$/g, "");
}
function slugifyTitle(title) {
    return normalizeSlug(title);
}
function slugifyUid(uid) {
    return `${uid ?? ""}`
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/-+/g, "-")
        .replace(/^-|-$/g, "");
}
function buildSlugSeed(args) {
    const preferredSlug = normalizeSlug(args.rawSlug);
    if (preferredSlug)
        return preferredSlug;
    const titleSlug = slugifyTitle(args.title);
    if (titleSlug)
        return titleSlug;
    return slugifyUid(args.uid);
}
function normalizeSlugAliases(values, exclude = "") {
    if (!Array.isArray(values))
        return [];
    const normalizedExclude = normalizeSlug(exclude);
    const seen = new Set();
    return values
        .map((value) => normalizeSlug(value))
        .filter((alias) => {
        if (!alias || alias === normalizedExclude || seen.has(alias)) {
            return false;
        }
        seen.add(alias);
        return true;
    });
}
function hasPrimaryData(data) {
    return `${data?.data ?? ""}`.trim().length > 0;
}
function hasTabData(data) {
    return Array.isArray(data?.tabs) &&
        data.tabs.some((tab) => `${tab ?? ""}`.trim().length > 0);
}
function hasRenderableContent(data) {
    return hasPrimaryData(data) || hasTabData(data);
}
function shouldIncludeInIndex(uid, data, allDocs) {
    const title = `${data?.title ?? ""}`.trim();
    if (!title)
        return false;
    if (uid.includes("|")) {
        const canonicalUid = uid.split("|").pop()?.trim() ?? "";
        const canonicalDoc = allDocs.get(canonicalUid);
        if (!canonicalDoc || !hasRenderableContent(canonicalDoc)) {
            return false;
        }
    }
    return hasRenderableContent(data) || uid.includes("~") || uid.includes("|");
}
function getListTableName(itemUid) {
    let tableName = itemUid.trim();
    if (tableName === "D1")
        tableName = "D";
    tableName = tableName
        .replace(/[0-9].*/, "")
        .replace(/[A-Z].*~/, "");
    if (tableName.includes("|")) {
        tableName = tableName
            .split("|")[0]
            .replace(/[0-9].*/, "");
    }
    return tableName;
}
function parentHasVisibleChildren(uid, includedUids) {
    if (!uid.includes("~"))
        return true;
    const childSeed = uid.split("~")[1]?.trim() ?? "";
    const tableName = getListTableName(childSeed);
    if (!tableName)
        return false;
    for (const candidateUid of includedUids) {
        if (candidateUid === uid)
            continue;
        if (tableName === candidateUid.split("~")[0] ||
            tableName === candidateUid.replace(/[0-9].*/, "")) {
            return true;
        }
    }
    return false;
}
function normalizeDayPatterns(value) {
    if (typeof value === "string") {
        const pattern = value.trim();
        return pattern || undefined;
    }
    if (Array.isArray(value)) {
        const patterns = value
            .map((pattern) => `${pattern ?? ""}`.trim())
            .filter((pattern) => pattern.length > 0);
        return patterns.length > 0 ? patterns : undefined;
    }
    return undefined;
}
function isSlugAvailable(slugOwners, slug, currentUid) {
    const owner = slugOwners.get(slug);
    return owner == null || owner === currentUid;
}
function makeUniqueSlug(slugOwners, baseSlug, currentUid) {
    const normalizedBase = normalizeSlug(baseSlug);
    const fallbackBase = normalizedBase || slugifyUid(currentUid) || "zikr";
    if (isSlugAvailable(slugOwners, fallbackBase, currentUid)) {
        return fallbackBase;
    }
    let suffix = 2;
    while (true) {
        const candidate = `${fallbackBase}-${suffix}`;
        if (isSlugAvailable(slugOwners, candidate, currentUid)) {
            return candidate;
        }
        suffix += 1;
    }
}
function buildResolvedSlugData(includedUids, allDocs) {
    const slugOwners = new Map();
    const resolvedByUid = new Map();
    for (const uid of [...includedUids].sort()) {
        const data = allDocs.get(uid);
        const explicitSlug = normalizeSlug(data?.slug);
        const explicitAliases = normalizeSlugAliases(data?.slugAliases, explicitSlug);
        if (explicitSlug) {
            slugOwners.set(explicitSlug, uid);
        }
        explicitAliases.forEach((alias) => {
            if (!slugOwners.has(alias)) {
                slugOwners.set(alias, uid);
            }
        });
        resolvedByUid.set(uid, {
            slug: explicitSlug,
            slugAliases: explicitAliases,
        });
    }
    for (const uid of [...includedUids].sort()) {
        const data = allDocs.get(uid);
        const resolved = resolvedByUid.get(uid);
        if (resolved?.slug)
            continue;
        const generatedSlug = makeUniqueSlug(slugOwners, buildSlugSeed({
            uid,
            title: `${data?.title ?? ""}`.trim(),
            rawSlug: data?.slug,
        }), uid);
        slugOwners.set(generatedSlug, uid);
        resolvedByUid.set(uid, {
            slug: generatedSlug,
            slugAliases: resolved?.slugAliases ?? [],
        });
    }
    return resolvedByUid;
}
function addSlugLookup(slugLookup, slug, uid, label) {
    if (!slug)
        return;
    const existingOwner = slugLookup[slug];
    if (existingOwner && existingOwner !== uid) {
        console.warn(`Duplicate ${label} "${slug}" for ${uid}; keeping ${existingOwner}`);
        return;
    }
    slugLookup[slug] = uid;
}
async function rebuildZikrIndex() {
    const snapshot = await db.collection("zikr").get();
    const allDocs = new Map();
    const sortedDocs = [...snapshot.docs].sort((a, b) => a.id.localeCompare(b.id));
    sortedDocs.forEach((doc) => {
        allDocs.set(doc.id, doc.data());
    });
    const includedUids = new Set();
    for (const doc of sortedDocs) {
        const data = allDocs.get(doc.id);
        if (shouldIncludeInIndex(doc.id, data, allDocs)) {
            includedUids.add(doc.id);
        }
    }
    let removedParentInPass = true;
    while (removedParentInPass) {
        removedParentInPass = false;
        for (const uid of [...includedUids]) {
            if (!uid.includes("~"))
                continue;
            if (parentHasVisibleChildren(uid, includedUids))
                continue;
            includedUids.delete(uid);
            removedParentInPass = true;
        }
    }
    const resolvedSlugData = buildResolvedSlugData(includedUids, allDocs);
    const index = {};
    const slugLookup = {};
    for (const uid of [...includedUids].sort()) {
        const data = allDocs.get(uid);
        const resolved = resolvedSlugData.get(uid) ?? {
            slug: "",
            slugAliases: [],
        };
        const item = {
            title: `${data?.title ?? ""}`.trim(),
            hasData: hasRenderableContent(data) || uid.includes("~") || uid.includes("|"),
        };
        if (resolved.slug) {
            item.slug = resolved.slug;
            addSlugLookup(slugLookup, resolved.slug, uid, "slug");
        }
        if (resolved.slugAliases.length > 0) {
            item.slugAliases = resolved.slugAliases;
            resolved.slugAliases.forEach((alias) => {
                addSlugLookup(slugLookup, alias, uid, "slug alias");
            });
        }
        if (typeof data?.order === "number" && Number.isFinite(data.order)) {
            item.order = data.order;
        }
        const day = normalizeDayPatterns(data?.day);
        if (day != null) {
            item.day = day;
        }
        index[uid] = item;
    }
    await db.doc("zikr_meta/index").set({
        items: index,
        slugLookup,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        itemCount: Object.keys(index).length,
    });
    return Object.keys(index).length;
}
// Rebuilds the public zikr index only when an admin explicitly requests publish.
exports.buildZikrIndex = functions.firestore
    .onDocumentWritten("zikr_meta/publish_requests", async (event) => {
    if (!event.data?.after.exists) {
        return;
    }
    const afterData = event.data.after.data();
    const beforeData = event.data.before.exists ? event.data.before.data() : null;
    const requestId = afterData?.requestId?.toString() ?? "";
    const previousRequestId = beforeData?.requestId?.toString() ?? "";
    if (!requestId || requestId == previousRequestId) {
        return;
    }
    const requestRef = event.data.after.ref;
    try {
        await requestRef.set({
            status: "running",
            startedAt: admin.firestore.FieldValue.serverTimestamp(),
            error: admin.firestore.FieldValue.delete(),
            processedRequestId: admin.firestore.FieldValue.delete(),
            itemCount: admin.firestore.FieldValue.delete(),
        }, { merge: true });
        const itemCount = await rebuildZikrIndex();
        console.log(`Index rebuilt: ${itemCount} items`);
        await requestRef.set({
            status: "success",
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            processedRequestId: requestId,
            itemCount,
            error: admin.firestore.FieldValue.delete(),
        }, { merge: true });
    }
    catch (error) {
        console.error("Error building index:", error);
        await requestRef.set({
            status: "error",
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            processedRequestId: requestId,
            error: error instanceof Error ? error.message : String(error),
        }, { merge: true });
        throw error;
    }
});
//# sourceMappingURL=index.js.map