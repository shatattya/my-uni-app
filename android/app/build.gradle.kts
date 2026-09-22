import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use {
        keystoreProperties.load(it)
    }
}

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ssr.myuniapp.cse"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "ssr.myuniapp.cse"

        minSdk = 26
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
                ?: throw GradleException(
                    "Missing 'keyAlias' in android/key.properties"
                )

            keyPassword = keystoreProperties.getProperty("keyPassword")
                ?: throw GradleException(
                    "Missing 'keyPassword' in android/key.properties"
                )

            storePassword = keystoreProperties.getProperty("storePassword")
                ?: throw GradleException(
                    "Missing 'storePassword' in android/key.properties"
                )

            val storeFilePath = keystoreProperties.getProperty("storeFile")
                ?: throw GradleException(
                    "Missing 'storeFile' in android/key.properties"
                )

            val releaseKeystore = file(storeFilePath)

            if (!releaseKeystore.exists()) {
                throw GradleException(
                    "Release keystore not found: ${releaseKeystore.absolutePath}"
                )
            }

            storeFile = releaseKeystore
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
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.0.4"
    )
}
