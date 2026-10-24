import java.util.Base64
import java.util.Properties
import com.android.build.api.dsl.ApplicationExtension

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Native Firebase resources are required for FCM before Dart starts. Emulator
// builds initialize demo-ruma explicitly and must not initialize the real project.
val rumaEmulatorBuild = (project.findProperty("dart-defines") as String?).orEmpty().split(",")
    .filter { it.isNotEmpty() }.map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
    .contains("AUTH_EMULATOR=true")
if (!rumaEmulatorBuild) apply(plugin = "com.google.gms.google-services")

val rumaSigning = Properties()
val rumaSigningFile = rootProject.file("key.properties")
if (rumaSigningFile.exists()) rumaSigningFile.inputStream().use { rumaSigning.load(it) }

extensions.configure<ApplicationExtension> {
    namespace = "id.ruma.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.ruma.app"
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
        create("release") {
            if (rumaSigningFile.exists()) {
                storeFile = file(rumaSigning.getProperty("storeFile"))
                storePassword = rumaSigning.getProperty("storePassword")
                keyAlias = rumaSigning.getProperty("keyAlias")
                keyPassword = rumaSigning.getProperty("keyPassword")
            }
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

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
