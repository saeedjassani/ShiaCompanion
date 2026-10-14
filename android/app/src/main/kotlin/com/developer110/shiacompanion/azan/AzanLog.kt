package com.developer110.shiacompanion.azan

import android.util.Log
import com.google.firebase.crashlytics.FirebaseCrashlytics

/**
 * Logcat, plus Crashlytics for anything that means an Azan may not have
 * played: those happen on someone's phone at prayer time, with nobody
 * watching, and a non-fatal is the only way to learn how often.
 */
internal object AzanLog {
    fun info(tag: String, message: String) {
        Log.i(tag, message)
        crashlytics { it.log("$tag: $message") }
    }

    fun warn(tag: String, message: String) {
        Log.w(tag, message)
        crashlytics { it.log("$tag: $message") }
    }

    fun error(tag: String, message: String, error: Throwable? = null) {
        Log.e(tag, message, error)
        crashlytics {
            it.log("$tag: $message")
            it.recordException(error ?: AzanPlaybackException(message))
        }
    }

    private inline fun crashlytics(block: (FirebaseCrashlytics) -> Unit) {
        try {
            block(FirebaseCrashlytics.getInstance())
        } catch (e: Exception) {
            // Firebase not initialised in this process; logcat has it.
        }
    }
}

internal class AzanPlaybackException(message: String) : Exception(message)
