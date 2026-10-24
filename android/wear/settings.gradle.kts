// The Wear OS app is its own Gradle build, not a module of the phone app's
// android/ build: Flutter runs `assembleRelease`/`bundleRelease` across every
// project in android/settings.gradle, so including this there would build,
// sign and slow down the watch app on every phone build. Kept apart, nothing
// the phone pipeline does (CI's APK, the Play internal-testing upload) can
// ever pick the watch app up by accident. See docs/WEAR_OS.md.
pluginManagement {
    repositories {
        google()
        // Google's mirror of Maven Central, ahead of Central itself, which
        // rate-limits shared CI runners.
        maven("https://maven-central.storage-download.googleapis.com/maven2/")
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        maven("https://maven-central.storage-download.googleapis.com/maven2/")
        mavenCentral()
    }
}

rootProject.name = "ShiaCompanionWear"
include(":app")
