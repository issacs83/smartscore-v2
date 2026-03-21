# SmartScore Module A - Build Instructions

## Prerequisites

### Required Software
- Flutter 3.2+ (with Dart 3.2+)
- Xcode 14+ (iOS development)
- Android Studio with NDK (Android development)
- Visual Studio 2022 (Windows development, optional)

### Installation

```bash
# Install Flutter (if not already installed)
git clone https://github.com/flutter/flutter.git
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor

# Get Flutter packages
flutter pub get
```

## Project Setup

### Clone and Navigate

```bash
# Clone SmartScore repository
git clone <smartscore-repo>
cd smartscore_v2/modules/A_app_shell

# Get dependencies
flutter pub get

# Build runner (for generated files, if needed)
flutter pub run build_runner build --delete-conflicting-outputs
```

## Development Builds

### Run on Connected Device

```bash
# List connected devices
flutter devices

# Run with development flavor
flutter run --flavor dev -t lib/main.dart

# Run on specific device
flutter run --flavor dev -d <device-id> -t lib/main.dart

# Run with hot reload enabled (default)
flutter run --flavor dev
```

### Run on Emulator/Simulator

**iOS Simulator**:
```bash
# Open simulator
open -a Simulator

# Run app
flutter run --flavor dev -d booted
```

**Android Emulator**:
```bash
# Launch AVD from Android Studio or:
emulator -avd <avd-name>

# Run app
flutter run --flavor dev -d emulator-5554
```

### Web Development

```bash
# Run on Chrome (default)
flutter run -d chrome --flavor dev

# Run on Firefox
flutter run -d firefox --flavor dev

# Enable web profile (verbose)
flutter run -d chrome --flavor dev --dart-define=FLUTTER_WEB_USE_SKIA=true
```

## Testing

### Unit and Widget Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/integration_test.dart

# Run with coverage
flutter test --coverage

# Run specific test by name
flutter test -k "App opens"

# Watch mode (re-run on file change)
flutter test --watch

# Fail fast on first failure
flutter test --fail-fast
```

### Integration Tests

```bash
# Run integration tests
flutter test integration_test/app_test.dart

# Run on physical device
flutter drive --target=integration_test/app_test.dart -d <device-id>

# Run with verbose output
flutter drive --target=integration_test/app_test.dart --verbose
```

### Code Coverage

```bash
# Generate coverage report
flutter test --coverage

# Convert to HTML report (requires lcov)
lcov --remove coverage/lcov.info 'lib/generated/*' -o coverage/lcov.info
genhtml -o coverage/html coverage/lcov.info

# Open report
open coverage/html/index.html
```

## Production Builds

### Build for iOS

**Requirements**:
- Apple Developer account
- Code signing certificate and provisioning profile

```bash
# Build iOS app
flutter build ios --flavor prod --release

# Build and output IPA
flutter build ipa --flavor prod --release

# Output location: build/ios/ipa/smartscore.ipa

# For distribution via App Store, use Xcode:
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release archive
```

### Build for Android

**Requirements**:
- Android keystore for signing
- Android SDK 24+ (API level 24+)

```bash
# Build APK
flutter build apk --flavor prod --release

# Build App Bundle (for Google Play)
flutter build appbundle --flavor prod --release

# Output locations:
# - APK: build/app/outputs/flutter-apk/app-release.apk
# - AAB: build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

**Signing Configuration**:

Create `android/key.properties`:
```properties
storePassword=<keystore-password>
keyPassword=<key-password>
keyAlias=smartscore_key
storeFile=<path-to-keystore.jks>
```

```bash
# Build signed APK
flutter build apk --flavor prod --release

# Build signed AAB
flutter build appbundle --flavor prod --release
```

### Build for macOS

```bash
# Build macOS app
flutter build macos --flavor prod --release

# Output: build/macos/Build/Products/Release/smartscore.app

# Create DMG (macOS installer)
# Use third-party tools or Xcode
```

### Build for Windows

```bash
# Build Windows app
flutter build windows --flavor prod --release

# Output: build/windows/runner/Release/

# Create MSIX installer
flutter pub add msix
flutter pub run msix:create
```

### Build for Web

```bash
# Build web app
flutter build web --flavor prod --release

# Output: build/web/

# Serve locally
flutter run -d chrome --flavor prod

# Deploy to hosting (e.g., Firebase)
firebase deploy
```

## Configuration Management

### Build Flavors

**Development (dev)**:
```bash
flutter run --flavor dev -t lib/main.dart
```

Environment:
- `DEBUG_MODE = true`
- `/debug` route enabled
- Verbose logging
- Feature flags: all enabled

**Production (prod)**:
```bash
flutter run --flavor prod -t lib/main.dart
```

Environment:
- `DEBUG_MODE = false`
- `/debug` route disabled
- Minimal logging
- Feature flags: per config

### Define Variables at Build Time

```bash
# Set debug flag
flutter run --dart-define=DEBUG_MODE=true

# Set multiple flags
flutter run \
  --dart-define=FLAVOR=dev \
  --dart-define=DEBUG_MODE=true \
  --dart-define=API_ENDPOINT=http://localhost:8000
```

### Environment Files

Create `.env.dev` and `.env.prod`:

```bash
# .env.dev
FLAVOR=dev
DEBUG_MODE=true
API_ENDPOINT=http://localhost:8000
ENABLE_DEMO_MODE=false

# .env.prod
FLAVOR=prod
DEBUG_MODE=false
API_ENDPOINT=https://api.smartscore.app
ENABLE_DEMO_MODE=false
```

Load in code:
```dart
// lib/config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

final flavor = dotenv.env['FLAVOR'] ?? 'prod';
final apiEndpoint = dotenv.env['API_ENDPOINT'] ?? 'https://api.smartscore.app';
```

## Performance Profiling

### Use DevTools

```bash
# Run app with DevTools
flutter run

# Open DevTools in browser
flutter pub global run devtools

# Connect to running app: http://localhost:9100
```

**Key profiling features**:
- Timeline: Frame rendering time
- Memory: Heap snapshots, memory growth
- CPU: CPU profiler (Dart-side)
- Performance: FPS, render times
- Network: HTTP/HTTPS requests

### Command-line Profiling

```bash
# Capture performance timeline
flutter drive --profile --target=lib/main.dart

# View timeline
# Output in: timeline_summary.json

# Memory profiling
dart --vm-service=localhost:8888 lib/main.dart
```

### Performance Targets (Stage 1)

| Metric | Target | Notes |
|--------|--------|-------|
| Cold startup | < 2s (p95) | Full app load |
| Hot reload | < 1s | Development only |
| Route navigation | < 150ms | Page transition |
| Page render (Module F) | < 100ms | Single page |
| Hit test latency | < 10ms | Tap response |
| Device action latency | < 100ms | Pedal/keyboard input |
| Library query (100 scores) | < 100ms | Full list load |
| Memory baseline | < 200MB | Idle state |
| Memory peak | < 500MB | Peak usage |

## Continuous Integration

### GitHub Actions Example

Create `.github/workflows/flutter.yml`:

```yaml
name: Flutter CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.2.0'

      - name: Get packages
        run: flutter pub get

      - name: Run tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.2.0'

      - name: Build web
        run: flutter build web --flavor prod --release

      - name: Upload web build
        uses: actions/upload-artifact@v3
        with:
          name: web-build
          path: build/web/
```

## Troubleshooting

### Common Issues

**Issue**: "flutter: command not found"
```bash
# Solution: Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"
```

**Issue**: "Gradle build failed"
```bash
# Solution: Clean and rebuild
flutter clean
flutter pub get
flutter build apk --flavor dev
```

**Issue**: "iOS pod install failed"
```bash
# Solution: Update pods
cd ios
pod repo update
pod install --repo-update
cd ..
```

**Issue**: "Dart SDK version mismatch"
```bash
# Solution: Use exact version
flutter downgrade 3.2.0
```

**Issue**: "Android NDK not found"
```bash
# Solution: Install NDK
# In Android Studio: SDK Manager → SDK Tools → NDK (Side by side)
```

## Release Checklist

Before releasing to stores:

- [ ] All tests passing: `flutter test --coverage`
- [ ] Code coverage > 80%: Check coverage/html/index.html
- [ ] Performance metrics within SLAs
- [ ] No compiler warnings: `flutter analyze`
- [ ] Lint checks pass: `flutter analyze --no-pub-check`
- [ ] Version bumped: `pubspec.yaml`
- [ ] Changelog updated: `CHANGELOG.md`
- [ ] Release notes prepared
- [ ] Git tag created: `git tag v1.0.0`
- [ ] Signed APK/IPA built: `flutter build apk/ipa --flavor prod --release`
- [ ] Signed App Bundle built: `flutter build appbundle --flavor prod --release`
- [ ] Tested on physical devices (iOS + Android)
- [ ] Accessibility verified: screen reader, text scaling
- [ ] Localization verified: strings.arb complete
- [ ] Privacy policy compliant: no secrets in build
- [ ] App signing certificates valid and not expired

## Post-Build

### Running the Built App

**Android**:
```bash
# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Or use Play Store Console for AAB
```

**iOS**:
```bash
# Install IPA on device
ios-deploy -b build/ios/ipa/smartscore.ipa

# Or use Xcode
```

**macOS**:
```bash
# Run .app
open build/macos/Build/Products/Release/smartscore.app
```

**Windows**:
```bash
# Run executable
build\windows\runner\Release\smartscore.exe
```

**Web**:
```bash
# Serve locally
python3 -m http.server --directory build/web 8000

# Or deploy to Firebase Hosting
firebase deploy
```

## References

- [Flutter Official Documentation](https://flutter.dev/docs)
- [Flutter Build Modes](https://flutter.dev/docs/testing/build-modes)
- [Flutter Flavors Guide](https://flutter.dev/docs/deployment/flavors)
- [Flutter Performance](https://flutter.dev/docs/perf)
- [Dart DevTools](https://dart.dev/tools/dart-devtools)
