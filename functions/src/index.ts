import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

type ZikrDocumentData = FirebaseFirestore.DocumentData;

interface ZikrIndexItem {
  title: string;
  slug?: string;
  slugAliases?: string[];
  hasData: boolean;
  order?: number;
  day?: string | string[];
}

interface ResolvedSlugData {
  slug: string;
  slugAliases: string[];
}

function normalizeSlug(value: unknown): string {
  return `${value ?? ""}`
    .toLowerCase()
    .replace(/[^\w\s-]/g, " ")
    .replace(/[_\s]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

function slugifyTitle(title: unknown): string {
  return normalizeSlug(title);
}

function slugifyUid(uid: unknown): string {
  return `${uid ?? ""}`
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

function buildSlugSeed(args: {
  uid: string;
  title: string;
  rawSlug?: unknown;
}): string {
  const preferredSlug = normalizeSlug(args.rawSlug);
  if (preferredSlug) return preferredSlug;

  const titleSlug = slugifyTitle(args.title);
  if (titleSlug) return titleSlug;

  return slugifyUid(args.uid);
}

function normalizeSlugAliases(values: unknown, exclude = ""): string[] {
  if (!Array.isArray(values)) return [];

  const normalizedExclude = normalizeSlug(exclude);
  const seen = new Set<string>();
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

function hasPrimaryData(data: ZikrDocumentData | undefined): boolean {
  return `${data?.data ?? ""}`.trim().length > 0;
}

function hasTabData(data: ZikrDocumentData | undefined): boolean {
  return Array.isArray(data?.tabs) &&
    data.tabs.some((tab: unknown) => `${tab ?? ""}`.trim().length > 0);
}

function hasRenderableContent(data: ZikrDocumentData | undefined): boolean {
  return hasPrimaryData(data) || hasTabData(data);
}

function shouldIncludeInIndex(
  uid: string,
  data: ZikrDocumentData | undefined,
  allDocs: Map<string, ZikrDocumentData>,
): boolean {
  const title = `${data?.title ?? ""}`.trim();
  if (!title) return false;

  if (uid.includes("|")) {
    const canonicalUid = uid.split("|").pop()?.trim() ?? "";
    const canonicalDoc = allDocs.get(canonicalUid);
    if (!canonicalDoc || !hasRenderableContent(canonicalDoc)) {
      return false;
    }
  }

  return hasRenderableContent(data) || uid.includes("~") || uid.includes("|");
}

function getListTableName(itemUid: string): string {
  let tableName = itemUid.trim();
  if (tableName === "D1") tableName = "D";

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

function parentHasVisibleChildren(uid: string, includedUids: Set<string>): boolean {
  if (!uid.includes("~")) return true;

  const childSeed = uid.split("~")[1]?.trim() ?? "";
  const tableName = getListTableName(childSeed);
  if (!tableName) return false;

  for (const candidateUid of includedUids) {
    if (candidateUid === uid) continue;

    if (
      tableName === candidateUid.split("~")[0] ||
      tableName === candidateUid.replace(/[0-9].*/, "")
    ) {
      return true;
    }
  }

  return false;
}

function normalizeDayPatterns(value: unknown): string | string[] | undefined {
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

function isSlugAvailable(
  slugOwners: Map<string, string>,
  slug: string,
  currentUid: string,
): boolean {
  const owner = slugOwners.get(slug);
  return owner == null || owner === currentUid;
}

function makeUniqueSlug(
  slugOwners: Map<string, string>,
  baseSlug: string,
  currentUid: string,
): string {
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

function buildResolvedSlugData(
  includedUids: Set<string>,
  allDocs: Map<string, ZikrDocumentData>,
): Map<string, ResolvedSlugData> {
  const slugOwners = new Map<string, string>();
  const resolvedByUid = new Map<string, ResolvedSlugData>();

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
    if (resolved?.slug) continue;

    const generatedSlug = makeUniqueSlug(
      slugOwners,
      buildSlugSeed({
        uid,
        title: `${data?.title ?? ""}`.trim(),
        rawSlug: data?.slug,
      }),
      uid,
    );

    slugOwners.set(generatedSlug, uid);
    resolvedByUid.set(uid, {
      slug: generatedSlug,
      slugAliases: resolved?.slugAliases ?? [],
    });
  }

  return resolvedByUid;
}

function addSlugLookup(
  slugLookup: {[key: string]: string},
  slug: string,
  uid: string,
  label: string,
): void {
  if (!slug) return;

  const existingOwner = slugLookup[slug];
  if (existingOwner && existingOwner !== uid) {
    console.warn(`Duplicate ${label} "${slug}" for ${uid}; keeping ${existingOwner}`);
    return;
  }
  slugLookup[slug] = uid;
}

async function rebuildZikrIndex(): Promise<number> {
  const snapshot = await db.collection("zikr").get();
  const allDocs = new Map<string, ZikrDocumentData>();
  const sortedDocs = [...snapshot.docs].sort((a, b) => a.id.localeCompare(b.id));

  sortedDocs.forEach((doc) => {
    allDocs.set(doc.id, doc.data());
  });

  const includedUids = new Set<string>();
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
      if (!uid.includes("~")) continue;
      if (parentHasVisibleChildren(uid, includedUids)) continue;

      includedUids.delete(uid);
      removedParentInPass = true;
    }
  }

  const resolvedSlugData = buildResolvedSlugData(includedUids, allDocs);
  const index: {[key: string]: ZikrIndexItem} = {};
  const slugLookup: {[key: string]: string} = {};

  for (const uid of [...includedUids].sort()) {
    const data = allDocs.get(uid);
    const resolved = resolvedSlugData.get(uid) ?? {
      slug: "",
      slugAliases: [],
    };

    const item: ZikrIndexItem = {
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
export const buildZikrIndex = functions.firestore
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
      }, {merge: true});

      const itemCount = await rebuildZikrIndex();
      console.log(`Index rebuilt: ${itemCount} items`);

      await requestRef.set({
        status: "success",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        processedRequestId: requestId,
        itemCount,
        error: admin.firestore.FieldValue.delete(),
      }, {merge: true});
    } catch (error) {
      console.error("Error building index:", error);
      await requestRef.set({
        status: "error",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        processedRequestId: requestId,
        error: error instanceof Error ? error.message : String(error),
      }, {merge: true});
      throw error;
    }
  });

/** Days of per-day usage counters to keep. All-time totals are never pruned. */
const USAGE_RETENTION_DAYS = 400;

/**
 * Trims the per-day usage tree.
 *
 * The dashboard never looks back further than a month, but the tree gains a
 * node every day and nothing else would ever remove one. All-time totals live
 * under `usage/totals` and are unaffected.
 */
export const pruneUsageCounters = functions.scheduler.onSchedule(
  {schedule: "every day 04:00", timeZone: "UTC"},
  async () => {
    const cutoff = new Date();
    cutoff.setUTCDate(cutoff.getUTCDate() - USAGE_RETENTION_DAYS);
    const cutoffKey = cutoff.toISOString().slice(0, 10);

    const dailyRef = admin.database().ref("usage/daily");
    const stale = await dailyRef
      .orderByKey()
      .endBefore(cutoffKey)
      .once("value");

    const removals: Record<string, null> = {};
    stale.forEach((child) => {
      if (child.key) removals[child.key] = null;
      return false;
    });

    const count = Object.keys(removals).length;
    if (count === 0) {
      console.log("No usage buckets older than " + cutoffKey);
      return;
    }

    await dailyRef.update(removals);
    console.log(`Pruned ${count} usage buckets older than ${cutoffKey}`);
  }
);
