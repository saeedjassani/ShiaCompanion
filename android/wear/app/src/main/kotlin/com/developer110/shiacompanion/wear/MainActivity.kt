package com.developer110.shiacompanion.wear

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.mutableStateOf
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.lifecycleScope
import com.developer110.shiacompanion.wear.counter.CounterStore
import com.developer110.shiacompanion.wear.data.PhoneLink
import com.developer110.shiacompanion.wear.data.SnapshotRepository
import com.developer110.shiacompanion.wear.data.SurfaceUpdater
import com.developer110.shiacompanion.wear.ui.WearApp
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private val route = mutableStateOf<String?>(null)
    private lateinit var phoneLink: PhoneLink

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        phoneLink = PhoneLink(this)
        route.value = intent?.getStringExtra(EXTRA_ROUTE)

        setContent {
            WearApp(
                repository = SnapshotRepository.get(this),
                counter = CounterStore.get(this),
                phoneLink = phoneLink,
                startRoute = route.value,
                onRouteConsumed = { route.value = null },
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra(EXTRA_ROUTE)?.let { route.value = it }
    }

    override fun onResume() {
        super.onResume()
        // Catch up on anything synced while closed, then ask the phone for
        // the latest - the same pull the Apple Watch app makes on opening.
        lifecycleScope.launch {
            phoneLink.catchUp()
            phoneLink.requestSnapshot()
        }
    }

    override fun onPause() {
        // The last chance to push a debounced count to the complication
        // before the app may be stopped.
        SurfaceUpdater.flushCounter(this)
        super.onPause()
    }

    companion object {
        const val EXTRA_ROUTE = "com.developer110.shiacompanion.wear.ROUTE"

        fun intent(context: Context, route: String): Intent =
            Intent(context, MainActivity::class.java)
                .putExtra(EXTRA_ROUTE, route)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }
}
