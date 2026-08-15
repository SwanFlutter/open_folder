# راهنمای GitHub Actions برای Flutter Plugin Package

> **هدف:** هر بار که پکیج Flutter جدید می‌نویسی، این فایل را مرور کن تا CI از اول اوکی باشه.

---

## ۱. چک‌لیست قبل از اولین Push

### ۱.۱ iOS — هماهنگی Deployment Target (مهم‌ترین)

یکی از رایج‌ترین دلایل شکست CI، ناهماهنگی deployment target بین این سه فایل است:

| فایل | مکان | چه می‌کند |
|---|---|---|
| `Package.swift` | `ios/PLUGIN_NAME/Package.swift` | deployment target برای Swift Package Manager |
| `*.podspec` | `ios/*.podspec` | deployment target برای CocoaPods (CI از این استفاده می‌کند) |
| `project.pbxproj` | `example/ios/Runner.xcodeproj/project.pbxproj` | deployment target برای example app |

**قانون طلایی:** هر سه باید یک عدد یکسان داشته باشند.

```ruby
# *.podspec
s.platform = :ios, '14.0'
```

```swift
// Package.swift
platforms: [
    .iOS("14.0")
],
```

```
# project.pbxproj (سه بار باید این مقدار باشد)
IPHONEOS_DEPLOYMENT_TARGET = 14.0;
```

> دام مهم: Podfile در .gitignore است و در CI وجود ندارد.
> پس deployment target حتماً از project.pbxproj خوانده می‌شود.

---

### ۱.۲ iOS — قوانین Swift API Availability

هر API که در نسخه‌های بالاتر iOS اضافه شده باید گارد داشته باشد:

```swift
// درست
if #available(iOS 14, *) {
    safe.success(status == .authorized || status == .limited)
} else {
    safe.success(status == .authorized)
}

// اشتباه — بدون گارد کامپایل نمی‌شود
safe.success(status == .authorized || status == .limited)
```

| Framework | حداقل iOS | نکته |
|---|---|---|
| `UniformTypeIdentifiers` (UTType) | iOS 14 | از `MobileCoreServices` برای iOS 13 استفاده کن |
| `PHAuthorizationStatus.limited` | iOS 14 | در PHPhotoLibrary |
| `PHPhotoLibrary.requestAuthorization(for:)` | iOS 14 | نسخه قدیم بدون for: برای iOS 13 |

---

### ۱.۳ macOS — هماهنگی Deployment Target

```ruby
# *.podspec
s.platform = :osx, '10.14'
```

```swift
// Package.swift
platforms: [
    .macOS("10.14")
],
```

---

### ۱.۴ Android — نکات مهم

```groovy
// android/build.gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21   // با pubspec.yaml هماهنگ کن
        targetSdkVersion 34
    }
}
```

---

## ۲. ساختار صحیح GitHub Actions Workflow

### ۲.۱ قانون کلی: بیلد به جای تست Integration

**روش قدیمی (مشکل‌دار) — الگوی کامل واقعی:**
```yaml
- name: Boot iOS Simulator
  run: |
    SIMULATOR_UDID=$(xcrun simctl create "iPhone 15" com.apple.CoreSimulator.SimDeviceType.iPhone-15)
    xcrun simctl boot "$SIMULATOR_UDID"
    echo "SIMULATOR_UDID=$SIMULATOR_UDID" >> $GITHUB_ENV

- name: Run integration tests on iOS Simulator
  run: |
    set -o pipefail
    flutter test integration_test/plugin_integration_test.dart \
      -d "$SIMULATOR_UDID" \
      --reporter=expanded \
      --timeout=600s 2>&1 | tee ios_test.log
    if [ $? -ne 0 ]; then
      echo "===== BUILD/TEST LOG TAIL ====="
      tail -n 200 ios_test.log
      exit 1
    fi
```

**مشکلات این روش:**
- نیاز به بوت simulator (۱–۲ دقیقه اضافه)
- نیاز به code signing معتبر
- خطاهای Swift compiler مستقیماً CI را می‌شکنند
- `set -o pipefail` و `tee` هیچ کمکی به خطای ریشه‌ای نمی‌کنند
- حدود ۵–۸ دقیقه زمان در مقابل ۱ دقیقه build

**روش صحیح:**
```yaml
- name: Build iOS example app (no code signing)
  working-directory: example
  run: flutter build ios --no-codesign --debug
```
اگر build شد = پلاگین OK است. بدون simulator، بدون signing، حدود ۱ دقیقه.

> **قانون:** `flutter test integration_test/` نیاز به دیوایس واقعی یا simulator بوت‌شده دارد.
> `flutter build` فقط کامپایل می‌کند و برای CI کافی است.

---

### ۲.۲ Template کامل iOS — فایل: `.github/workflows/ios_build.yml`

```yaml
name: iOS Build Check

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  ios-build:
    name: Build iOS Example App
    runs-on: macos-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x.x'
          channel: 'stable'
          cache: true

      - name: Install dependencies (plugin root)
        run: flutter pub get

      - name: Analyze Dart/Flutter code
        run: flutter analyze --no-fatal-infos

      - name: Run unit tests
        run: flutter test --reporter=expanded

      - name: Install dependencies (example app)
        working-directory: example
        run: flutter pub get

      - name: Build iOS example app (no code signing)
        working-directory: example
        run: flutter build ios --no-codesign --debug
```

---

### ۲.۳ Template کامل Android — فایل: `.github/workflows/android_build.yml`

```yaml
name: Android Build Check

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  android-build:
    name: Build Android Example App
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x.x'
          channel: 'stable'
          cache: true

      - name: Install dependencies (plugin root)
        run: flutter pub get

      - name: Analyze Dart/Flutter code
        run: flutter analyze --no-fatal-infos

      - name: Run unit tests
        run: flutter test --reporter=expanded

      - name: Install dependencies (example app)
        working-directory: example
        run: flutter pub get

      - name: Build Android APK (example app)
        working-directory: example
        run: flutter build apk --debug
```

---

### ۲.۴ Template کامل macOS — فایل: `.github/workflows/macos_build.yml`

```yaml
name: macOS Build Check

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  macos-build:
    name: Build macOS Example App
    runs-on: macos-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x.x'
          channel: 'stable'
          cache: true

      - name: Install dependencies (plugin root)
        run: flutter pub get

      - name: Analyze Dart/Flutter code
        run: flutter analyze --no-fatal-infos

      - name: Run unit tests
        run: flutter test --reporter=expanded

      - name: Install dependencies (example app)
        working-directory: example
        run: flutter pub get

      - name: Build macOS example app
        working-directory: example
        run: flutter build macos --debug
```

---

### ۲.۵ Template کامل Linux — فایل: `.github/workflows/linux_build.yml`

```yaml
name: Linux Build Check

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  linux-build:
    name: Build Linux Example App
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Linux build dependencies
        run: |
          sudo apt-get update -y
          sudo apt-get install -y \
            clang cmake git \
            ninja-build pkg-config \
            libgtk-3-dev liblzma-dev \
            libstdc++-12-dev

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Enable Linux desktop
        run: flutter config --enable-linux-desktop

      - name: Install dependencies (plugin root)
        run: flutter pub get

      - name: Analyze Dart/Flutter code
        run: flutter analyze --no-fatal-infos

      - name: Run unit tests
        run: flutter test --reporter=expanded

      - name: Install dependencies (example app)
        working-directory: example
        run: flutter pub get

      - name: Build Linux example app
        working-directory: example
        run: flutter build linux --debug
```

> **نکته Linux:** بدون مرحله `Install Linux build dependencies` بیلد با خطای `clang not found` یا `GTK not found` شکست می‌خورد.

---

### ۲.۶ Template Dart Unit Tests — فایل: `.github/workflows/dart_tests.yml`

```yaml
name: Dart Unit Tests

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  dart-tests:
    name: Dart Unit Tests
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x.x'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run static analysis
        run: flutter analyze --no-fatal-infos

      - name: Run unit tests with coverage
        run: flutter test --coverage --reporter=expanded

      - name: Upload coverage (optional)
        uses: codecov/codecov-action@v4
        with:
          file: coverage/lcov.info
```

---

## ۳. چک‌لیست نهایی قبل از Push

```
── pubspec ──────────────────────────────────────────────────────
[ ] pubspec.yaml    --> version دارد (مثلاً 0.1.0+1)  ← بدون این Xcode warning می‌دهد
[ ] pubspec.yaml    --> sdk: '>=3.0.0 <4.0.0'

── iOS ──────────────────────────────────────────────────────────
[ ] ios/*.podspec   --> s.platform با Package.swift یکسان است
[ ] project.pbxproj --> IPHONEOS_DEPLOYMENT_TARGET یکسان با podspec (۳ بار)
[ ] Swift APIs      --> همه API های جدید داخل #available() گارد شدند
[ ] CI workflow     --> از flutter build ios --no-codesign استفاده می‌کند (نه integration test)

── macOS ─────────────────────────────────────────────────────────
[ ] macos/*.podspec --> s.platform با Package.swift یکسان است

── Linux ─────────────────────────────────────────────────────────
[ ] linux workflow  --> مرحله apt-get install libgtk-3-dev وجود دارد
[ ] linux workflow  --> flutter config --enable-linux-desktop قبل از build است

── Android ──────────────────────────────────────────────────────
[ ] Android APIs    --> داخل Build.VERSION.SDK_INT چک شدند

── عمومی ────────────────────────────────────────────────────────
[ ] flutter analyze --> صفر error
[ ] flutter test    --> همه پاس
[ ] flutter build ios --no-codesign --debug  --> موفق (تست لوکال)
[ ] flutter build apk --debug                --> موفق (تست لوکال)
[ ] flutter build macos --debug              --> موفق (تست لوکال)
[ ] flutter build linux --debug              --> موفق (تست لوکال)
[ ] example/lib/main.dart --> وجود دارد و runApp دارد
[ ] .github/workflows/    --> workflow فایل‌ها وجود دارند
```

---

## ۴. خطاهای رایج و راه‌حل سریع

| خطا | علت | راه‌حل |
|---|---|---|
| `'limited' is only available in iOS 14` | deployment target کمتر از 14 | podspec و pbxproj را به 14.0 برسان |
| `Module 'Foundation' has no member 'UTType'` | UniformTypeIdentifiers روی iOS 13 | deployment target را به 14.0 برسان |
| `Missing build name (CFBundleShortVersionString)` | فیلد `version` در pubspec.yaml نیست | `version: 0.1.0+1` به pubspec اضافه کن |
| `Missing build number (CFBundleVersion)` | همان علت بالا | همان راه‌حل بالا — هر دو warning از یک مشکل هستند |
| `Could not build the application for the simulator` | deployment target مغشوش یا روش integration test | podspec/Package.swift/pbxproj را هم‌تراز کن؛ از `flutter build ios --no-codesign` استفاده کن |
| `Unable to start the app on the device` | simulator بوت نشده یا build قبلاً fail شده | از `flutter build ios --no-codesign --debug` استفاده کن؛ نیازی به simulator نیست |
| `Failed to load integration_test/*.dart` | نتیجه مستقیم build failure قبل از آن است | خطای اصلی را در لاگ بالاتر پیدا کن (Swift Compiler Error) |
| `No Flutter engine found` | flutter pub get در example نشده | مرحله `Install dependencies (example app)` اضافه کن |
| `fatal: path example/ios/Podfile does not exist` | Podfile در .gitignore است | طبیعی است؛ deployment target را در pbxproj بگذار |
| `clang: not found` یا `GTK not found` (Linux) | پکیج‌های سیستمی Ubuntu نصب نیستند | مرحله `apt-get install libgtk-3-dev clang cmake ninja-build` اضافه کن |
| `Linux is not enabled` | flutter config تنظیم نشده | قبل از build، `flutter config --enable-linux-desktop` اجرا کن |
| CI هنوز step قدیمی نشان می‌دهد | لاگ از قبل از commit است | آخرین run در GitHub Actions را چک کن |

---

## ۵. فلوچارت تشخیص مشکل CI

```
CI شکست خورد
     |
     |-- Integration Test / Simulator Error?
     |        |
     |        |-- "Unable to start the app on the device"
     |        |-- "Failed to load integration_test/*.dart"
     |        |        --> خطای اصلی را در همان لاگ بالاتر پیدا کن
     |        |        --> روش CI را به flutter build --no-codesign تغییر بده
     |        |
     |        +-- "Some tests failed" (بدون علت مشخص)
     |                 --> لاگ Swift Compiler Error را جستجو کن
     |
     |-- Swift Compiler Error?
     |        |
     |        |-- "only available in iOS X"
     |        |        --> deployment target را در podspec و pbxproj بالا ببر
     |        |
     |        +-- "Module has no member" (مثلاً UTType)
     |                 --> deployment target را بالا ببر یا #available گارد اضافه کن
     |
     |-- "Could not build the application for the simulator"
     |        --> از flutter build ios --no-codesign --debug استفاده کن
     |
     |-- "Missing build name" / "Missing build number"
     |        --> version: x.y.z+n را به pubspec.yaml اضافه کن
     |
     |-- Linux Build Error?
     |        |
     |        |-- "clang: not found" / "GTK not found"
     |        |        --> apt-get install libgtk-3-dev clang cmake ninja-build
     |        |
     |        +-- "Linux is not enabled"
     |                 --> flutter config --enable-linux-desktop اضافه کن
     |
     +-- Dart Analyze Error?
              --> flutter analyze را لوکال اجرا کن
              --> اگر CI پاس نمی‌کند: --no-fatal-infos اضافه کن
```

---

*این سند از درس‌های واقعی پروژه‌های `media_manager` و `open_folder` استخراج شده است.*

---

## ۶. ترتیب اولویت تشخیص خطا در لاگ CI

وقتی CI شکست می‌خورد و لاگ طولانی است، **از پایین به بالا** بخوان:

```
1. آخرین خطا معمولاً نتیجه خطای قبلی است (مثلاً "Failed to load" نتیجه build failure است)
2. دنبال "Swift Compiler Error" یا "Error:" بگرد
3. فایل و خط را یادداشت کن (مثلاً MediaManagerPlugin.swift:36)
4. خطا را در جدول بخش ۴ جستجو کن
```

**مثال واقعی از لاگ:**
```
Swift Compiler Error (Xcode): 'limited' is only available in iOS 14 or newer
  → MediaManagerPlugin.swift:36
Swift Compiler Error (Xcode): Module 'Foundation' has no member named 'UTType'
  → MediaManagerPlugin.swift:256
Could not build the application for the simulator.
Failed to load integration_test/plugin_integration_test.dart   ← نتیجه، نه علت!
Some tests failed.                                              ← نتیجه، نه علت!
```
علت اصلی: deployment target پایین‌تر از iOS 14 است.
