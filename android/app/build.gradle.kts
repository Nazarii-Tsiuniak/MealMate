import java.io.File
import java.security.KeyStore
import java.security.cert.X509Certificate

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val offlineStorePath = providers.environmentVariable("MEALMATE_OFFLINE_KEYSTORE").orNull
val offlineStorePassword = providers.environmentVariable("MEALMATE_OFFLINE_STORE_PASSWORD").orNull
val offlineKeyAlias = providers.environmentVariable("MEALMATE_OFFLINE_KEY_ALIAS").orElse("mealmate-offline").get()
val offlineKeyPassword = providers.environmentVariable("MEALMATE_OFFLINE_KEY_PASSWORD").orNull ?: offlineStorePassword
val offlineSigningReady = !offlineStorePath.isNullOrBlank() && !offlineStorePassword.isNullOrBlank() && !offlineKeyPassword.isNullOrBlank()

fun verifyOfflineSigning() {
    if (!offlineSigningReady) {
        throw GradleException("Offline release requires a private keystore and signing environment variables. See ANDROID_RELEASE.md. Debug signing is not allowed.")
    }
    val store = file(offlineStorePath!!)
    if (!store.isFile) throw GradleException("Offline release keystore was not found. See ANDROID_RELEASE.md.")
    try {
        val keys = KeyStore.getInstance("PKCS12")
        store.inputStream().use { keys.load(it, offlineStorePassword!!.toCharArray()) }
        if (!keys.isKeyEntry(offlineKeyAlias) || offlineKeyAlias == "androiddebugkey") {
            throw GradleException("Offline release requires its own private signing key.")
        }
        val certificate = keys.getCertificate(offlineKeyAlias) as? X509Certificate
            ?: throw GradleException("Offline signing certificate is missing.")
        if (certificate.subjectX500Principal.name.contains("CN=Android Debug", ignoreCase = true)) {
            throw GradleException("Android Debug certificates are forbidden for offline release.")
        }
    } catch (error: GradleException) {
        throw error
    } catch (_: Exception) {
        throw GradleException("Cannot open the offline signing keystore. Check the path, alias and password locally.")
    }
}

android {
    namespace = "com.example.mealmate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.mealmate"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("offlineRelease") {
            if (offlineSigningReady) {
                storeFile = file(offlineStorePath!!)
                storePassword = offlineStorePassword
                keyAlias = offlineKeyAlias
                keyPassword = offlineKeyPassword
                storeType = "PKCS12"
            }
        }
    }

    flavorDimensions += "mode"
    productFlavors {
        create("server") {
            dimension = "mode"
        }
        create("offline") {
            dimension = "mode"
            applicationIdSuffix = ".offline"
            signingConfig = signingConfigs.getByName("offlineRelease")
        }
    }

    buildTypes {
        release {
            signingConfig = null
        }
    }
}

tasks.matching { it.name.startsWith("compileFlutterBuildOffline") }.configureEach {
    doFirst {
        val root = rootProject.projectDir.parentFile
        val target = providers.gradleProperty("target").orElse("lib/main.dart").get()
        val selected = File(target).let { if (it.isAbsolute) it else root.resolve(target) }
        if (selected.canonicalFile != root.resolve("lib/main_offline.dart").canonicalFile) {
            throw GradleException("Offline flavor must use --target lib/main_offline.dart.")
        }
        if (name.endsWith("Release")) verifyOfflineSigning()
    }
}
tasks.register("verifyOfflineReleaseSigning") {
    doLast { verifyOfflineSigning() }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
