package com.developer110.shiacompanion.wear

import android.content.SharedPreferences

/** An in-memory stand-in for the watch's preferences. */
internal class FakePreferences : SharedPreferences {
    private val values = mutableMapOf<String, Any?>()

    override fun getAll(): MutableMap<String, *> = values

    override fun getString(key: String?, defValue: String?): String? =
        values[key] as? String ?: defValue

    override fun getStringSet(
        key: String?,
        defValues: MutableSet<String>?,
    ): MutableSet<String>? = defValues

    override fun getInt(key: String?, defValue: Int): Int = values[key] as? Int ?: defValue

    override fun getLong(key: String?, defValue: Long): Long =
        values[key] as? Long ?: defValue

    override fun getFloat(key: String?, defValue: Float): Float =
        values[key] as? Float ?: defValue

    override fun getBoolean(key: String?, defValue: Boolean): Boolean =
        values[key] as? Boolean ?: defValue

    override fun contains(key: String?): Boolean = values.containsKey(key)

    override fun edit(): SharedPreferences.Editor = FakeEditor(values)

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    private class FakeEditor(private val stored: MutableMap<String, Any?>) :
        SharedPreferences.Editor {
        private val pending = mutableMapOf<String, Any?>()
        private var cleared = false

        override fun putString(key: String?, value: String?) = apply {
            if (key != null) pending[key] = value
        }

        override fun putStringSet(key: String?, values: MutableSet<String>?) = this

        override fun putInt(key: String?, value: Int) = apply {
            if (key != null) pending[key] = value
        }

        override fun putLong(key: String?, value: Long) = apply {
            if (key != null) pending[key] = value
        }

        override fun putFloat(key: String?, value: Float) = apply {
            if (key != null) pending[key] = value
        }

        override fun putBoolean(key: String?, value: Boolean) = apply {
            if (key != null) pending[key] = value
        }

        override fun remove(key: String?) = apply { if (key != null) pending.remove(key) }

        override fun clear() = apply { cleared = true }

        override fun commit(): Boolean {
            if (cleared) stored.clear()
            stored.putAll(pending)
            return true
        }

        override fun apply() {
            commit()
        }
    }
}
