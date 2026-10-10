import java.io.File
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

fun loadDotEnv(): Map<String, String> {
    // Project root is two levels up from android/app
    val envFile = File(project.projectDir.parentFile.parentFile, ".env")
    if (!envFile.exists()) return emptyMap()

    return envFile.readLines()
        .filter { it.isNotBlank() && !it.trimStart().startsWith("#") }
        .associate { line ->
            val parts = line.split("=", limit = 2)
            require(parts.size == 2) { "Invalid .env entry: $line" }
            val key = parts[0].trim()
            val value = parts[1].trim().removeSurrounding("\"").removeSurrounding("'")
            key to value
        }
}

val dotEnv = loadDotEnv()

fun loadKeyProperties(): Properties {
    val props = Properties()
    val propsFile = File(rootDir, "key.properties")
    if (propsFile.exists()) {
        propsFile.inputStream().use { props.load(it) }
    }
    return props
}

val keyProps = loadKeyProperties()

val releaseStoreFile = keyProps.getProperty("RELEASE_STORE_FILE") ?: providers.gradleProperty("RELEASE_STORE_FILE").orNull
val releaseStorePassword = keyProps.getProperty("RELEASE_STORE_PASSWORD") ?: providers.gradleProperty("RELEASE_STORE_PASSWORD").orNull
val releaseKeyAlias = keyProps.getProperty("RELEASE_KEY_ALIAS") ?: providers.gradleProperty("RELEASE_KEY_ALIAS").orNull
val releaseKeyPassword = keyProps.getProperty("RELEASE_KEY_PASSWORD") ?: providers.gradleProperty("RELEASE_KEY_PASSWORD").orNull
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "com.rusobrg.roastnrizz"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.rusobrg.roastnrizz"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        resConfigs("en", "pt", "pt-rPT", "pt-rBR", "es", "fr", "de", "it", "ru", "zh", "ja", "ko", "ar", "hi", "tr", "vi", "id", "th", "pl", "nl", "el", "bn")
        manifestPlaceholders["ADMOB_APP_ID"] =
            dotEnv["ADMOB_APP_ID_ANDROID"] ?: "ca-app-pub-3940256099942544~3347511713" // Use test ID as fallback
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            @Suppress("DEPRECATION")
            isCrunchPngs = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}

if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } &&
    !hasReleaseSigning
) {
    error(
        "Release signing is not configured. Supply RELEASE_STORE_FILE, " +
            "RELEASE_STORE_PASSWORD, RELEASE_KEY_ALIAS and RELEASE_KEY_PASSWORD."
    )
}
