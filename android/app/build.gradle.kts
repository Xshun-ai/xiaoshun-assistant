import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun requireKeystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)
        ?: throw GradleException("Missing '$name' in android/key.properties")

android {
    namespace = "io.github.xshunai.campusassistant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.xshunai.campusassistant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = requireKeystoreProperty("keyAlias")
                keyPassword = requireKeystoreProperty("keyPassword")
                storeFile = rootProject.file(requireKeystoreProperty("storeFile"))
                storePassword = requireKeystoreProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (!keystorePropertiesFile.exists()) {
                throw GradleException(
                    "Release builds require android/key.properties and a release keystore",
                )
            }
            signingConfig = signingConfigs.getByName("release")
            isDebuggable = false
        }
    }
}

flutter {
    source = "../.."
}
