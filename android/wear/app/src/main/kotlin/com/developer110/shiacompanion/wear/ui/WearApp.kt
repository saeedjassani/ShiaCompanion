package com.developer110.shiacompanion.wear.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import com.developer110.shiacompanion.wear.counter.CounterStore
import com.developer110.shiacompanion.wear.data.PhoneLink
import com.developer110.shiacompanion.wear.data.SnapshotRepository
import kotlinx.coroutines.launch

/** The screens the app can be sent to from outside: the tile and the complications. */
object Routes {
    const val HOME = "home"
    const val CALENDAR = "calendar"
    const val COUNTER = "counter"

    val all = setOf(HOME, CALENDAR, COUNTER)
}

@Composable
fun WearApp(
    repository: SnapshotRepository,
    counter: CounterStore,
    phoneLink: PhoneLink,
    startRoute: String?,
    onRouteConsumed: () -> Unit,
) {
    val navController = rememberSwipeDismissableNavController()
    val snapshot by repository.snapshot.collectAsState()
    val counterState by counter.state.collectAsState()
    val isRequesting by phoneLink.isRequesting.collectAsState()
    val problem by phoneLink.problem.collectAsState()
    val scope = rememberCoroutineScope()

    ShiaCompanionTheme {
        AppScaffold {
            SwipeDismissableNavHost(navController = navController, startDestination = Routes.HOME) {
                composable(Routes.HOME) {
                    HomeScreen(
                        snapshot = snapshot,
                        isRequesting = isRequesting,
                        problem = problem,
                        onSync = { scope.launch { phoneLink.requestSnapshot() } },
                        onOpenCalendar = { navController.navigate(Routes.CALENDAR) { launchSingleTop = true } },
                        onOpenCounter = { navController.navigate(Routes.COUNTER) { launchSingleTop = true } },
                    )
                }
                composable(Routes.CALENDAR) { CalendarScreen(snapshot) }
                composable(Routes.COUNTER) {
                    CounterScreen(
                        state = counterState,
                        onAdjust = counter::adjust,
                        onReset = counter::reset,
                        onCycleTarget = counter::cycleTarget,
                    )
                }
            }
        }
    }

    // A tap on a complication or the tile lands on the screen it was showing,
    // with home underneath so swiping back still works. Replacing rather than
    // stacking: a second tap leaves one copy of the screen, not two.
    LaunchedEffect(startRoute) {
        val route = startRoute?.takeIf { it in Routes.all && it != Routes.HOME } ?: return@LaunchedEffect
        navController.navigate(route) {
            popUpTo(Routes.HOME)
            launchSingleTop = true
        }
        onRouteConsumed()
    }
}
