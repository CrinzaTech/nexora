import java.util.Properties
import java.io.FileInputStream

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

// ── Release signing ──────────────────────────────────────────────────
// Credentials live in android/key.properties (gitignored). When the
// file is absent — fresh clone, CI without secrets, etc. — release
// builds fall back to the debug keystore so `flutter run --release`
// still works locally; a Play-Store-targeted build MUST have
// key.properties present or it'd ship debug-signed and Play would
// reject the upload.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.crinesta.crinza"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Todo: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nex.ora"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only register the `release` config when key.properties is
        // present — otherwise we'd reference null storeFile and gradle
        // would fail to evaluate even for debug builds.
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                // rootProject.file(…) resolves relative to /android, so
                // key.properties can use a bare filename for a keystore
                // sitting next to it in /android — the Flutter docs'
                // canonical layout. file(…) on its own would resolve
                // against /android/app and miss the keystore.
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Release signing if key.properties was loaded; falls back
            // to debug keys (with warning) so `flutter run --release`
            // works on machines without the keystore.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "⚠️  Release build is signing with the DEBUG keystore — " +
                    "android/key.properties not found. Play Store will reject " +
                    "this AAB. Run keystore setup before publishing."
                )
                signingConfigs.getByName("debug")
            }
            // R8 + resource shrinking. Reflection-heavy SDKs (Razorpay,
            // Syncfusion, Firebase, video_player, etc.) need explicit
            // -keep rules; those live in proguard-rules.pro. If the
            // release build starts crashing after a new dependency
            // lands, the first thing to check is whether it needs its
            // own -keep block.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // Android 15 introduced 16 KB memory pages on supported devices. AGP
    // 8.5.1+ already aligns uncompressed jniLibs to 16 KB inside the APK
    // when this is `false` (the default in AGP 8.0+), but stating it
    // explicitly survives any future default change and makes the
    // alignment contract visible at the build-config level. The residual
    // "ELF alignment check failed" warning that some plugins still
    // trigger comes from their own prebuilt .so files being linked with
    // a 4 KB max-page-size — that has to be fixed upstream by bumping
    // the plugin.
    packaging {
        jniLibs {
            useLegacyPackaging = false
            // rootbeer-0.1.0's prebuilt libtoolChecker.so (pulled in
            // transitively by flutter_jailbreak_detection's Android side)
            // is 4 KB-aligned and the last release upstream — no newer
            // build exists to bump to. It's safe to drop: RootBeer is only
            // instantiated inside that plugin's "jailbroken" method
            // handler, and DeviceSecurityGuard._checkJailbroken() only
            // ever calls that channel on iOS (Android security relies on
            // developer-mode detection instead, see
            // lib/core/security/device_security_guard.dart) — so this
            // native lib is dead weight on Android. If Android-side root
            // detection is ever wired up, remove this exclude first or
            // RootBeer.isRooted will throw UnsatisfiedLinkError.
             excludes += setOf("**/libtoolChecker.so")
        }
    }

    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    }
}

// better_player_plus (live class), just_audio, and video_player_android each
// bundle their own androidx.media3 version (1.3.1 / 1.4.1 / 1.9.2
// respectively). Gradle's default "highest wins" conflict resolution picks
// 1.9.2 for the whole app, but better_player_plus 1.0.8 was compiled against
// 1.3.1's API and calls `ExoPlayer.getAudioComponent()`, which no longer
// exists on 1.9.2 — that mismatch is a runtime NoSuchMethodError, not a
// build-time error, so it only shows up when the live-class player actually
// starts. Force every media3 artifact to the version better_player_plus
// expects so the whole app links against one consistent API surface.
configurations.all {
    resolutionStrategy {
        val media3Version = "1.3.1"
        force(
            "androidx.media3:media3-common:$media3Version",
            "androidx.media3:media3-ui:$media3Version",
            "androidx.media3:media3-session:$media3Version",
            "androidx.media3:media3-exoplayer:$media3Version",
            "androidx.media3:media3-exoplayer-hls:$media3Version",
            "androidx.media3:media3-exoplayer-dash:$media3Version",
            "androidx.media3:media3-exoplayer-rtsp:$media3Version",
            "androidx.media3:media3-exoplayer-smoothstreaming:$media3Version",
            "androidx.media3:media3-datasource-cronet:$media3Version",
            "androidx.media3:media3-datasource:$media3Version",
            "androidx.media3:media3-decoder:$media3Version",
            "androidx.media3:media3-extractor:$media3Version",
        )
    }
}

flutter {
    source = "../.."
}
