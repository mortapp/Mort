import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun dartDefine(name: String): String? {
    val encoded = project.findProperty("dart-defines")?.toString() ?: return null
    val values = encoded
        .split(",")
        .mapNotNull { value ->
            runCatching { String(Base64.getDecoder().decode(value), Charsets.UTF_8) }.getOrNull()
        }
        .filter { it.startsWith("$name=") }
        .map { it.substringAfter("=") }
        .distinct()
    if (values.size > 1) {
        throw GradleException("Conflicting Dart defines for $name.")
    }
    return values.singleOrNull()
}

val androidAdsEnabled = dartDefine("ADS_ENABLED") == "true"
val releaseProfile = dartDefine("MORT_RELEASE_PROFILE")
val releaseStage = dartDefine("MORT_RELEASE_STAGE")
if (androidAdsEnabled &&
    (releaseProfile in setOf("closed_test", "reviewer_demo") || releaseStage == "closed_test")
) {
    throw GradleException("ADS_ENABLED=true is forbidden for Android closed-test and reviewer builds.")
}

val localSigningProperties = Properties().apply {
    val localFile = rootProject.file("key.properties")
    if (localFile.isFile) {
        localFile.inputStream().use(::load)
    }
}

fun signingValue(environmentName: String, propertyName: String): String? =
    System.getenv(environmentName)?.takeIf { it.isNotBlank() }
        ?: localSigningProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }

val releaseStorePath = signingValue("MORT_UPLOAD_KEYSTORE_PATH", "storeFile")
val releaseStorePassword = signingValue("MORT_UPLOAD_STORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingValue("MORT_UPLOAD_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingValue("MORT_UPLOAD_KEY_PASSWORD", "keyPassword")
val releaseSigningValues = listOf(
    releaseStorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
)
val hasReleaseSigning = listOf(
    releaseStorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }
val hasPartialReleaseSigning = releaseSigningValues.any { !it.isNullOrBlank() }
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (hasPartialReleaseSigning && !hasReleaseSigning) {
    throw GradleException(
        "Android upload signing is incomplete. Set all MORT_UPLOAD_* values or android/key.properties.",
    )
}
if (releaseBuildRequested && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is required. Debug-signing fallback is intentionally disabled.",
    )
}
if (hasReleaseSigning && !file(releaseStorePath!!).isFile) {
    throw GradleException("The configured Android upload keystore does not exist.")
}

android {
    namespace = "com.mortapp.mobile"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.mortapp.mobile"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    if (!androidAdsEnabled) {
        // Use build-type priority so removals apply to both the app and the AARs.
        // These are the Flutter build types; the overlay retains debug/profile INTERNET.
        sourceSets.configureEach {
            if (name in setOf("debug", "profile", "release")) {
                manifest.srcFile("src/noAds/AndroidManifest.xml")
            }
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.7.1")
}

flutter {
    source = "../.."
}
