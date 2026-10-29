plugins {
    // Same versions as the phone app's android/settings.gradle, so the two
    // builds never need two toolchains.
    id("com.android.application") version "8.13.2" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.3.20" apply false
    id("io.github.takahirom.roborazzi") version "1.77.0" apply false
}
