# راهنمای رفع خطای AGP 9+ در پلاگین‌های Flutter

## مشکل

با ارتقا به Android Gradle Plugin (AGP) نسخه 9، دو خطای رایج رخ می‌دهد:

**خطای اول** — وقتی `android.builtInKotlin=true` باشد:
```
The 'org.jetbrains.kotlin.android' plugin is no longer required for Kotlin support since AGP 9.0.
```

**خطای دوم** — وقتی `android.newDsl=true` باشد:
```
ApplicationExtensionImpl cannot be cast to AbstractAppExtension
```

**ریشه مشکل:** Flutter 3.44 با AGP 9 فقط در حالت `builtInKotlin=false` + `newDsl=false` کار می‌کند. در این حالت Flutter Gradle Plugin و `integration_test` هر دو سالم اجرا می‌شوند. اما پلاگین‌هایی که `id("kotlin-android")` در بلاک `plugins {}` دارند توسط pub.dev به عنوان legacy KGP flag می‌شوند.

---

## محیط هدف

| ابزار | نسخه |
|---|---|
| Flutter | 3.44.x |
| Android Gradle Plugin (AGP) | 9.0.1 |
| Kotlin Gradle Plugin (KGP) | 2.2.20 |
| Java | 17+ |
| Gradle | 8.11+ |

---

## گام‌های اصلاح

### ۱. فایل `android/settings.gradle.kts` (پلاگین)

نسخه AGP و KGP را اعلام کن. AGP به نسخه `8.7.3` تنظیم شود (standalone build پلاگین) و KGP به `2.0.21`:

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("com.android.library") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

rootProject.name = "your_plugin_name"
```

---

### ۲. فایل `android/build.gradle.kts` (پلاگین)

**قبل (مشکل‌دار):**
```kotlin
plugins {
    id("com.android.library")
    id("kotlin-android")           // ← pub.dev این را legacy flag می‌کند
}

android {
    kotlinOptions {                 // ← این هم legacy است
        jvmTarget = "17"
    }
}
```

یا حالت دیگر با `buildscript`:
```kotlin
buildscript {
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")  // ← legacy
    }
}
```

**بعد (صحیح):**
```kotlin
group = "com.example.your_plugin"
version = "1.0-SNAPSHOT"

plugins {
    id("com.android.library")
    // kotlin-android را اینجا اضافه نکن
}

// KGP را فقط وقتی host آن را نخواسته apply کن.
// با builtInKotlin=true: AGP 9 خودش Kotlin را فراهم می‌کند → apply نکن
// با builtInKotlin=false: باید خودمان apply کنیم
val builtInKotlin = providers
    .gradleProperty("android.builtInKotlin")
    .orElse("false")
    .get()
    .trim()
    .equals("true", ignoreCase = true)

if (!builtInKotlin) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.your_plugin"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") { java.srcDirs("src/main/kotlin") }
        getByName("test") { java.srcDirs("src/test/kotlin") }
    }

    defaultConfig {
        minSdk = 24
    }
}

// به جای kotlinOptions از این استفاده کن (هر دو AGP 8 و AGP 9 را پشتیبانی می‌کند)
project.extensions.configure(
    org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java
) {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}
```

**چرا این روش کار می‌کند:**
- `id("kotlin-android")` در بلاک `plugins {}` وجود ندارد → pub.dev flag نمی‌زند
- KGP از طریق `apply(plugin = ...)` به صورت شرطی اعمال می‌شود
- `project.extensions.configure(KotlinAndroidProjectExtension)` هم با AGP 8 و هم AGP 9 کار می‌کند

---

### ۳. فایل `example/android/gradle.properties`

```properties
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G
android.useAndroidX=true
# flutter 3.44 + AGP 9: هر دو باید false باشند
android.newDsl=false
android.builtInKotlin=false
```

**توضیح:**
- `newDsl=false` → Flutter Gradle Plugin هنوز به DSL قدیمی نیاز دارد
- `builtInKotlin=false` → Flutter's `integration_test` که هنوز KGP apply می‌کند crash نمی‌کند

---

### ۴. فایل `example/android/settings.gradle.kts`

AGP 9 و KGP را اعلام کن تا `apply(plugin = ...)` در پلاگین بتواند resolve شود:

```kotlin
pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false  // ← لازم برای resolve
}

include(":app")
```

---

### ۵. فایل `example/android/app/build.gradle.kts`

`kotlin-android` و `kotlinOptions` را حذف کن — با `builtInKotlin=false` نیازی نیست:

```kotlin
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    // kotlin-android اینجا نباشد
}

android {
    namespace = "com.example.your_plugin_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.your_plugin_example"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// KGP 2.2+ پیش‌فرض JVM_21 دارد. برای هماهنگی با compileOptions باید صریحاً 17 تنظیم شود.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
```

---

### ۶. فایل `pubspec.yaml`

minimum Flutter را به `3.44.0` ارتقا بده:

```yaml
environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"
```

---

## خلاصه تغییرات

| فایل | تغییر کلیدی |
|---|---|
| `android/settings.gradle.kts` | AGP `8.7.3` + KGP `2.2.20` |
| `android/build.gradle.kts` | حذف `id("kotlin-android")` از plugins، اضافه کردن conditional `apply()` + `project.extensions.configure` |
| `example/android/gradle.properties` | `newDsl=false` + `builtInKotlin=false` |
| `example/android/settings.gradle.kts` | AGP `9.0.1` + KGP `2.2.20` اعلام شود |
| `example/android/app/build.gradle.kts` | حذف `id("kotlin-android")` و `kotlinOptions` |
| `pubspec.yaml` | `flutter: ">=3.44.0"` |

---

## جدول سازگاری نسخه‌ها

| Java | Gradle | AGP | KGP |
|---|---|---|---|
| 17 | 8.7+ | 8.5–8.7 | 1.9.x–2.0.x |
| 17 | 8.11+ | 9.0–9.x | 2.0.x–2.1.x |
| 21 | 8.11+ | 9.0–9.x | 2.0.x–2.1.x |

> منبع: [Gradle compatibility matrix](https://docs.gradle.org/current/userguide/compatibility.html) | [KGP compatibility](https://kotlinlang.org/docs/gradle-configure-project.html#apply-the-plugin)

---

## خطاهای رایج و راه‌حل

| خطا | دلیل | راه‌حل |
|---|---|---|
| `plugin is no longer required since AGP 9.0` | `builtInKotlin=true` + KGP apply شده | `builtInKotlin=false` کن یا KGP apply را حذف کن |
| `ApplicationExtensionImpl cannot be cast` | `newDsl=true` با Flutter GradlePlugin | `newDsl=false` کن |
| `Gradle Version: null` در `flutter analyze` | `settings.gradle.kts` نسخه AGP ندارد | نسخه AGP را در settings اعلام کن |
| `Cannot mutate classpath after resolved` | `buildscript {}` داخل `if` | `buildscript` را به سطح اول فایل منتقل کن یا حذف کن |
| `Unresolved reference: KotlinAndroidProjectExtension` | KGP apply نشده | شرط `builtInKotlin` را بررسی کن |
| `Inconsistent JVM-target: compileDebugJavaWithJavac (17) vs compileDebugKotlin (21)` | KGP 2.2+ پیش‌فرض `JVM_21` دارد ولی `compileOptions` روی `17` است | در `app/build.gradle.kts` بلاک `kotlin { compilerOptions { jvmTarget = JVM_17 } }` اضافه کن |
