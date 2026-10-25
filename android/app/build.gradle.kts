plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.matrimony_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.matrimony_app"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // ✅ ProGuard সক্রিয় করা হলো — CallKit ও Agora-র ক্লাস রাখতে
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Debug build-এ ProGuard বন্ধ থাকবে যাতে বিল্ড দ্রুত হয়
            isMinifyEnabled = false
            isShrinkResources = false
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

// ⚠️ Jitsi Meet + video_player conflict fix
// react-native-video (Jitsi-র ভেতরে) আর androidx.media3 (video_player)
// একই RtspMediaSource class duplicate করছিল — তাই exclude করলাম
configurations.all {
    exclude(group = "androidx.media3", module = "media3-exoplayer-rtsp")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}