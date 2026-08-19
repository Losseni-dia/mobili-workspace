plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}
android {
    namespace = "ci.mobili.mobile_app"
    // Forcé à 36 (au lieu de flutter.compileSdkVersion, resté à 34) — utile en soi (Play Store
    // exigera bientôt compileSdk >= 36) et combiné à l'override flutter_plugin_android_lifecycle
    // (voir pubspec.yaml) qui a réglé l'échec CI ":file_picker:checkReleaseAarMetadata" (ce
    // plugin dépend d'une version de flutter_plugin_android_lifecycle exigeant compileSdk 36,
    // alors que file_picker lui-même est encore publié compilé en compileSdk 34). targetSdk/
    // minSdk restent gérés par Flutter, indépendants du compileSdk (AGP 9.0.1 supporte 36 sans
    // souci).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    defaultConfig {
        applicationId = "ci.mobili.mobile_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        create("release") {
            storeFile = System.getenv("MOBILEAPP_KEYSTORE_PATH")?.let { file(it) }
            storePassword = System.getenv("MOBILEAPP_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("MOBILEAPP_KEY_ALIAS")
            keyPassword = System.getenv("MOBILEAPP_KEY_PASSWORD")
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
flutter {
    source = "../.."
}