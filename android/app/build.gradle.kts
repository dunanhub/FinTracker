import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties()
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (signingPropertiesFile.isFile) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
}

if (releaseBuildRequested) {
    if (!signingPropertiesFile.isFile) {
        throw GradleException(
            "Release signing requires android/key.properties. " +
                "Copy android/key.properties.example and set your private signing values."
        )
    }

    val requiredKeys = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
    val missingKeys = requiredKeys.filter { signingProperties.getProperty(it).isNullOrBlank() }
    if (missingKeys.isNotEmpty()) {
        throw GradleException(
            "Missing release signing properties in android/key.properties: " +
                missingKeys.joinToString(", ")
        )
    }

    val releaseKeystore = rootProject.file(signingProperties.getProperty("storeFile"))
    if (!releaseKeystore.isFile) {
        throw GradleException(
            "Release keystore not found. Check storeFile in android/key.properties."
        )
    }
}

android {
    namespace = "com.example.fin_tracker"
    compileSdk = flutter.compileSdkVersion
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.fin_tracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = signingProperties.getProperty("keyAlias")
            keyPassword = signingProperties.getProperty("keyPassword")
            storeFile = signingProperties.getProperty("storeFile")
                ?.takeIf { it.isNotBlank() }
                ?.let { rootProject.file(it) }
            storePassword = signingProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
