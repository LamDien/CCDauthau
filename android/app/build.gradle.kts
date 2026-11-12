import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProps = Properties().apply {
    listOf(
        rootProject.file("local.properties"),
        rootProject.file("../local.properties"),
    ).forEach { propsFile ->
        if (propsFile.exists()) {
            propsFile.inputStream().use { load(it) }
        }
    }
}

fun resolveAdConfig(vararg keys: String, defaultValue: String): String {
    for (key in keys) {
        val gradleProp = project.findProperty(key)?.toString()?.trim()
        if (!gradleProp.isNullOrEmpty()) return gradleProp

        val localProp = localProps.getProperty(key)?.trim()
        if (!localProp.isNullOrEmpty()) return localProp

        val envVar = System.getenv(key)?.trim()
        if (!envVar.isNullOrEmpty()) return envVar
    }
    return defaultValue
}

val admobAppId = resolveAdConfig(
    "ADMOB_ANDROID_APP_ID",
    "ADMOB_APP_ID",
    defaultValue = "ca-app-pub-3940256099942544~3347511713",
)
val admobBannerId = resolveAdConfig(
    "ADMOB_ANDROID_BANNER_ID",
    "ADMOB_BANNER_ID",
    defaultValue = "ca-app-pub-3940256099942544/9214589741",
)

android {
    namespace = "vn.ccdauthau.cc_dau_thau"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "vn.ccdauthau.luyenthi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppId
        manifestPlaceholders["admobBannerId"] = admobBannerId
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Signing with the debug keys for now if key.properties is not configured yet.
            signingConfig = signingConfigs.getByName("debug")
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

// Also export a version-tagged copy alongside app-release.apk without breaking Flutter CLI output lookup.
val releaseVersionName = android.defaultConfig.versionName ?: "1.0.0"
val releaseApkFile = layout.buildDirectory.file("outputs/apk/release/app-release.apk")
val flutterApkDir = layout.buildDirectory.dir("outputs/flutter-apk")

tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        val sourceApk = releaseApkFile.get().asFile
        if (sourceApk.exists()) {
            val targetDir = flutterApkDir.get().asFile
            targetDir.mkdirs()
            val targetApk = targetDir.resolve("CCDauthau-v$releaseVersionName.apk")
            sourceApk.copyTo(targetApk, overwrite = true)
            println("Exported versioned APK: ${targetApk.absolutePath}")
        }
    }
}
