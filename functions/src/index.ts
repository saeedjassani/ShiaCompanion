import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

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
