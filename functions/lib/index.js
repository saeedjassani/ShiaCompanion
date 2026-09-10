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
exports.pruneUsageCounters = void 0;
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
