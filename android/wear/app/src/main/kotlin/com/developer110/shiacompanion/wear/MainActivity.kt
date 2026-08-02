package com.developer110.shiacompanion.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { PrayerApp() }
    }

    override fun onResume() {
        super.onResume()
        // Render whatever has already synced, then ask the phone for anything newer.
        PhoneSyncManager.refreshFromSyncedData(this)
        PhoneSyncManager.requestSnapshot(this)
        PrayerSurfaces.scheduleNextRefresh(this)
    }
}
