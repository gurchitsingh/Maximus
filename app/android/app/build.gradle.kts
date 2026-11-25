import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: values come from app/android/key.properties (gitignored).
// Without that file a RELEASE build fails; it never falls back to the debug key.
// See docs/RELEASE_SIGNING.md.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.gurchit.maximus.maximus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.gurchit.maximus.maximus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(
                    keystoreProperties.getProperty("storeFile")
                        ?: throw GradleException("key.properties is missing storeFile")
                )
                storePassword = keystoreProperties.getProperty("storePassword")
                    ?: throw GradleException("key.properties is missing storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                    ?: throw GradleException("key.properties is missing keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                    ?: throw GradleException("key.properties is missing keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            }
            // No else branch on purpose: never use the debug key for release.
        }
    }
}

// Fail any release build early, with a clear message, when key.properties is absent.
gradle.taskGraph.whenReady {
    val releaseTask = allTasks.firstOrNull {
        it.project == project &&
            Regex("(assemble|bundle|package).*Release", RegexOption.IGNORE_CASE)
                .containsMatchIn(it.name)
    }
    if (releaseTask != null && !hasReleaseKey) {
        throw GradleException(
            "RELEASE SIGNING: app/android/key.properties not found. " +
                "Release builds are never signed with the debug key. " +
                "Create the upload key and key.properties as described in docs/RELEASE_SIGNING.md."
        )
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
