import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("io.github.takahirom.roborazzi")
}

// The watch app takes its version from the phone app's pubspec.yaml, so the
// two never disagree about which release they belong to.
//
// The version *code* is offset: Play keys version codes by package, across
// every form factor, so the watch build can never reuse one the phone has
// used. The upload job passes the exact code and name it picked from Play
// (-PwearVersionCode, -PwearVersionName; see
// android/scripts/next_play_version_code.sh and "Version codes" in
// docs/WEAR_OS.md).
val pubspecVersion: Pair<String, Int> = run {
    val line = rootDir.resolve("../../pubspec.yaml").readLines()
        .first { it.startsWith("version:") }
    val match = Regex("""version:\s*([0-9.]+)\+([0-9]+)""").find(line)
        ?: error("Unrecognised pubspec.yaml version line: $line")
    match.groupValues[1] to match.groupValues[2].toInt()
}
val wearVersionCodeOffset = 100_000

// android/key.properties is the phone app's upload key, written by CI's
// internal-testing job. The Data Layer only connects apps that share a
// package name *and* a signing certificate, so the watch app is signed with
// the same key or it never hears from the phone.
val keystoreProperties = Properties().apply {
    val file = rootDir.resolve("../key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.developer110.shiacompanion.wear"
    compileSdk = 36

    defaultConfig {
        // The phone app's package. Required by the Data Layer (see above), and
        // what makes Play list the watch app as the same app's Wear OS build.
        applicationId = "com.developer110.shiacompanion"
        // Wear OS 3, the oldest version Play still accepts new apps for.
        minSdk = 30
        targetSdk = 36
        versionCode = (findProperty("wearVersionCode") as String?)?.toInt()
            ?: (pubspecVersion.second + wearVersionCodeOffset)
        versionName = findProperty("wearVersionName") as String? ?: pubspecVersion.first
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (keystoreProperties.isNotEmpty()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        debug {
            // Matches the phone app's debug build, which is
            // com.developer110.shiacompanion.debug: a debug watch app pairs
            // with a debug phone app, and a release one with the store's.
            applicationIdSuffix = ".debug"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.systemProperty("robolectric.pixelCopyRenderMode", "hardware")
                // Robolectric downloads its Android jars itself, from Maven
                // Central unless told otherwise; the same mirror as above.
                it.systemProperty(
                    "robolectric.dependency.repo.url",
                    "https://maven-central.storage-download.googleapis.com/maven2",
                )
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

roborazzi {
    // Screenshots land in the build directory, not the repo: CI uploads
    // them as an artifact so a reviewer without a watch can see each screen.
    outputDir.set(layout.buildDirectory.dir("outputs/roborazzi"))
}

// Pinned to the newest releases that still build with the phone app's
// toolchain (AGP 8.13, compileSdk 36). Wear Compose 1.7 needs AGP 9.1 and
// compileSdk 37; move both builds up together.
dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.06.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.core:core-splashscreen:1.2.0")

    implementation("androidx.wear.compose:compose-material3:1.6.2")
    implementation("androidx.wear.compose:compose-foundation:1.6.2")
    implementation("androidx.wear.compose:compose-navigation:1.6.2")
    implementation("androidx.wear:wear-tooling-preview:1.0.0")

    implementation("androidx.wear.tiles:tiles:1.6.2")
    implementation("androidx.wear.protolayout:protolayout:1.4.2")
    implementation("androidx.wear.protolayout:protolayout-expression:1.4.2")
    implementation("androidx.wear.protolayout:protolayout-material3:1.4.2")
    implementation("androidx.wear.watchface:watchface-complications-data-source-ktx:1.3.0")
    implementation("com.google.guava:guava:33.4.8-android")

    implementation("com.google.android.gms:play-services-wearable:20.0.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")

    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    testImplementation("org.robolectric:robolectric:4.17")
    testImplementation("androidx.test:core:1.7.0")
    testImplementation(composeBom)
    testImplementation("androidx.compose.ui:ui-test-junit4")
    testImplementation("io.github.takahirom.roborazzi:roborazzi:1.77.0")
    testImplementation("io.github.takahirom.roborazzi:roborazzi-compose:1.77.0")
    testImplementation("io.github.takahirom.roborazzi:roborazzi-junit-rule:1.77.0")
}
