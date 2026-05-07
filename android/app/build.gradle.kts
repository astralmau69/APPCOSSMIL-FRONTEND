import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.cossmil.citamedicapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.cossmil.citamedicapp"
        // minSdk 21 = Android 5.0 (Lollipop) — máxima cobertura de dispositivos.
        // local_auth funciona en API 21+; en dispositivos sin biometría la app
        // simplemente desactiva esa opción en tiempo de ejecución.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // R8 (sucesor de ProGuard): minifica bytecode + elimina código muerto.
            // Reduce el tamaño del .aab y dificulta la ingeniería inversa.
            isMinifyEnabled = true
            // Elimina recursos (imágenes, layouts) que no son referenciados en código.
            // Requiere isMinifyEnabled = true para funcionar.
            isShrinkResources = true
            // Reglas base de Android + reglas del proyecto para no romper
            // plugins de Flutter que usan reflection (local_auth, etc.).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Fallback al ambiente debug si no existe la llave para evitar bloqueos
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Necesaria para enableEdgeToEdge() en MainActivity.onCreate().
    // FlutterFragmentActivity la pulla transitivamente, pero la declaramos
    // explícita para garantizar la versión que expone la extensión KTX.
    implementation("androidx.activity:activity-ktx:1.9.3")
}

flutter {
    source = "../.."
}
