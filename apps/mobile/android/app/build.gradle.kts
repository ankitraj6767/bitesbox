import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing ────────────────────────────────────────────────────────────
// Credentials live in android/key.properties, which is git-ignored. When the file
// is absent (a fresh clone, or CI running only `flutter build --debug`) the debug
// keystore is used so the build still succeeds; a release build then fails
// verification at upload time rather than silently shipping an unsigned artifact.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.containsKey("storeFile")

// ── Google Maps ───────────────────────────────────────────────────────────────
// The Android SDK reads its key from the manifest, which cannot see Dart defines.
// Supply it as a Gradle property (-PgoogleMapsKey=…), an environment variable, or
// in local.properties. Absent, embedded maps degrade to the maps-app hand-off.
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val googleMapsKey: String =
    (project.findProperty("googleMapsKey") as String?)
        ?: System.getenv("GOOGLE_MAPS_KEY")
        ?: localProperties.getProperty("googleMapsKey")
        ?: ""

android {
    namespace = "in.bitesbox.bitesbox"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "in.bitesbox.bitesbox"
        // 23 is the floor required by firebase_messaging and geolocator, and it
        // still covers effectively every handset in service in India.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["googleMapsKey"] = googleMapsKey
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }

        debug {
            // Lets a debug build sit alongside a store build on a rider's phone.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
