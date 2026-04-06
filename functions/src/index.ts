import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

function slugifyTitle(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^\w\s-]/g, " ")
    .replace(/[_\s]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

function normalizeSlugAliases(values: unknown, exclude?: string): string[] {
  if (!Array.isArray(values)) return [];

  const normalizedExclude = slugifyTitle(exclude ?? "");
  const seen = new Set<string>();
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

async function rebuildZikrIndex(): Promise<number> {
  const snapshot = await db.collection("zikr").get();
  const index: {
    [key: string]: {
      title: string;
      slug?: string;
      slugAliases?: string[];
      hasData: boolean;
      order?: number;
    };
  } = {};
  const slugLookup: {[key: string]: string} = {};

  const sortedDocs = [...snapshot.docs].sort((a, b) => a.id.localeCompare(b.id));
  sortedDocs.forEach((doc) => {
    const data = doc.data();
    if (data.title) {
      const hasPrimaryData = data.data && data.data.toString().trim();
      const hasTabData = Array.isArray(data.tabs) &&
        data.tabs.some((tab) => tab && tab.toString().trim());
      const slug = slugifyTitle(data.slug?.toString() ?? "");
      const slugAliases = normalizeSlugAliases(data.slugAliases, slug);

      const item: {
        title: string;
        slug?: string;
        slugAliases?: string[];
        hasData: boolean;
        order?: number;
      } = {
        title: data.title,
        hasData: !!hasPrimaryData || !!hasTabData || doc.id.includes("~") || doc.id.includes("|"),
      };
      if (slug) {
        item.slug = slug;
        if (slugLookup[slug] && slugLookup[slug] !== doc.id) {
          console.warn(`Duplicate slug "${slug}" for ${doc.id}; keeping ${slugLookup[slug]}`);
        } else {
          slugLookup[slug] = doc.id;
        }
      }
      if (slugAliases.length > 0) {
        item.slugAliases = slugAliases;
        slugAliases.forEach((alias) => {
          if (slugLookup[alias] && slugLookup[alias] !== doc.id) {
            console.warn(
              `Duplicate slug alias "${alias}" for ${doc.id}; keeping ${slugLookup[alias]}`,
            );
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
