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
    return encoded
        .split(",")
        .mapNotNull { value ->
            runCatching { String(Base64.getDecoder().decode(value)) }.getOrNull()
        }
        .firstOrNull { it.startsWith("$name=") }
        ?.substringAfter("=")
        ?.takeIf { it.isNotBlank() }
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
