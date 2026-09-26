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
exports.publishCommunityStats = exports.pruneUsageCounters = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
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
exports.pruneUsageCounters = functions.scheduler.onSchedule({ schedule: "every day 04:00", timeZone: "UTC" }, async () => {
    const cutoff = new Date();
    cutoff.setUTCDate(cutoff.getUTCDate() - USAGE_RETENTION_DAYS);
    const cutoffKey = cutoff.toISOString().slice(0, 10);
    const dailyRef = admin.database().ref("usage/daily");
    const stale = await dailyRef
        .orderByKey()
        .endBefore(cutoffKey)
        .once("value");
    const removals = {};
    stale.forEach((child) => {
        if (child.key)
            removals[child.key] = null;
        return false;
    });
    const count = Object.keys(removals).length;
    if (count === 0) {
        console.log("No usage buckets older than " + cutoffKey);
        return;
    }
    await dailyRef.update(removals);
    console.log(`Pruned ${count} usage buckets older than ${cutoffKey}`);
});
/** Where the public community summary is published. `database.rules.json`
 * makes exactly this node world-readable and client-unwritable. */
const COMMUNITY_PATH = "public/community";
/** How many days the "this week" figures and the sparkline cover. */
const COMMUNITY_WINDOW_DAYS = 7;
/** How many zikrs the "most recited this week" list carries. */
const COMMUNITY_TOP_COUNT = 5;
/** A zikr needs at least this many completions in the window to be listed,
 * so a list padded out by one person's reading is never shown as "the
 * community's". */
const COMMUNITY_TOP_MIN = 3;
/** The completion counter key suffix, see AnalyticsService.zikrCompleted. */
const DONE_SUFFIX = "~done";
function sumCounters(counters, predicate) {
    if (!counters)
        return 0;
    let total = 0;
    for (const [key, value] of Object.entries(counters)) {
        if (typeof value === "number" && predicate(key))
            total += value;
    }
    return total;
}
function dayKey(date) {
    return date.toISOString().slice(0, 10);
}
/**
 * Rolls the admin-only usage counters up into one small, public summary
 * (about 1-2KB) that every client can afford to fetch.
 *
 * The raw `usage` tree is far too big for every client to read, and letting
 * clients read it at all would expose per-feature numbers nobody opted in to
 * publishing. Clients instead read only `public/community`, at most a few
 * times a day (see CommunityStatsService), so 10k daily readers cost ~20MB
 * of Realtime Database download a day and no Firestore reads at all.
 *
 * Day buckets are keyed by each device's *local* date, so "today" in UTC can
 * already have a few entries for tomorrow from readers east of UTC; the
 * window runs up to and including tomorrow to catch them.
 */
exports.publishCommunityStats = functions.scheduler.onSchedule({ schedule: "every 60 minutes", timeZone: "UTC" }, async () => {
    const db = admin.database();
    const now = new Date();
    const dayKeys = [];
    for (let offset = COMMUNITY_WINDOW_DAYS - 1; offset >= -1; offset--) {
        const day = new Date(now);
        day.setUTCDate(day.getUTCDate() - offset);
        dayKeys.push(dayKey(day));
    }
    const dailyZikr = await Promise.all(dayKeys.map(async (key) => {
        const snapshot = await db.ref(`usage/daily/${key}/zikr`).once("value");
        return { key, counters: snapshot.val() };
    }));
    // Tomorrow's handful of early entries are folded into today rather than
    // shown as a day of their own.
    const tomorrow = dailyZikr.pop();
    const today = dailyZikr[dailyZikr.length - 1];
    if (tomorrow?.counters && today) {
        today.counters = { ...(today.counters ?? {}) };
        for (const [key, value] of Object.entries(tomorrow.counters)) {
            today.counters[key] = (today.counters[key] ?? 0) + value;
        }
    }
    const isDone = (key) => key.endsWith(DONE_SUFFIX);
    const isOpen = (key) => !key.endsWith(DONE_SUFFIX);
    const days = dailyZikr.map(({ key, counters }) => ({
        d: key,
        c: sumCounters(counters, isDone),
        o: sumCounters(counters, isOpen),
    }));
    const weeklyByZikr = {};
    for (const { counters } of dailyZikr) {
        if (!counters)
            continue;
        for (const [key, value] of Object.entries(counters)) {
            if (!isDone(key) || typeof value !== "number")
                continue;
            const uid = key.slice(0, -DONE_SUFFIX.length);
            weeklyByZikr[uid] = (weeklyByZikr[uid] ?? 0) + value;
        }
    }
    const topUids = Object.entries(weeklyByZikr)
        .filter(([, count]) => count >= COMMUNITY_TOP_MIN)
        .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
        .slice(0, COMMUNITY_TOP_COUNT);
    const top = await Promise.all(topUids.map(async ([uid, count]) => {
        const label = await db.ref(`usage/labels/zikr/${uid}`).once("value");
        const title = typeof label.val() === "string" ? label.val() : uid;
        return { uid, title, c: count };
    }));
    const totals = await db.ref("usage/totals/zikr").once("value");
    const totalCounters = totals.val();
    const summary = {
        v: 1,
        updatedAt: now.getTime(),
        week: {
            c: days.reduce((sum, day) => sum + day.c, 0),
            o: days.reduce((sum, day) => sum + day.o, 0),
        },
        allTime: {
            c: sumCounters(totalCounters, isDone),
            o: sumCounters(totalCounters, isOpen),
        },
        days,
        top,
    };
    await db.ref(COMMUNITY_PATH).set(summary);
    console.log(`Published community stats: ${summary.week.c} completions this week`);
});
//# sourceMappingURL=index.js.map