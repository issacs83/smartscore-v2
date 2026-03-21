# Stage 1 Build Analysis Report
**Date**: 2026-03-21
**Environment**: Cowork VM (Ubuntu 22, no Flutter SDK)
**Target**: Local build on Windows (C:\Users\issac\Desktop\JunTech\moveOnToNext)

## 1. Environment Status

| Tool | VM | Local (required) |
|------|-----|-----------------|
| Flutter SDK | NOT INSTALLED | Required 3.2+ |
| Dart SDK | NOT INSTALLED | Required 3.2+ |
| Python 3.10 | INSTALLED | For Stage 2 |
| OpenCV 4.13 | INSTALLED | For Stage 2 |

## 2. Static Analysis Results (VM-side)

**All 54 Dart files pass brace balance check: 0 errors.**

| Module | Dart Files | Lines | Test Files | Docs |
|--------|-----------|-------|------------|------|
| A_app_shell | 21 | 3,334 | 1 | 10 |
| B_score_input | 9 | 2,227 | 3 | 11 |
| E_music_normalizer | 6 | 3,559 | 3 | 5 |
| F_score_renderer | 9 | 3,404 | 3 | 8 |
| K_external_device | 9 | 2,202 | 2 | 7 |
| **Total** | **54** | **14,726** | **12** | **41** |

## 3. SDK Version Consistency

- A_app_shell: `sdk: '>=3.2.0 <4.0.0'` ← stricter, sets project minimum
- B, E, F, K: `sdk: '>=3.0.0 <4.0.0'`
- **Action**: Align all to `>=3.2.0 <4.0.0` for consistency

## 4. Cross-Module Dependencies

- Modules are self-contained (no direct cross-module imports in code)
- Integration happens through A_app_shell providers
- **Status**: CLEAN

## 5. Known Issues for Local Build

### Issue 1: Monorepo structure
Each module has its own `pubspec.yaml`. For a unified Flutter app build:
- **Option A**: Create root `pubspec.yaml` that includes modules as local packages (recommended)
- **Option B**: Merge all code into single Flutter project

### Issue 2: Module A import paths
Module A's providers reference other modules via abstract interfaces.
Local build needs concrete import paths configured.

### Issue 3: Platform-specific code
Module K (External Device) references `flutter_blue_plus` and platform channels.
Module G (Audio Capture, Stage 4) will need native Swift/Kotlin code.

## 6. Local Build Steps (Windows)

```powershell
# 1. Install Flutter SDK (if not installed)
# https://docs.flutter.dev/get-started/install/windows

# 2. Create unified Flutter project
flutter create smartscore_app
cd smartscore_app

# 3. Copy module code into lib/
# See INTEGRATION_GUIDE.md for detailed merge instructions

# 4. Install dependencies
flutter pub get

# 5. Run analysis
flutter analyze

# 6. Run tests
flutter test

# 7. Run on target platform
flutter run -d chrome    # Web
flutter run -d windows   # Windows desktop
```

## 7. Supported Platforms (Stage 1)

| Platform | Status | Notes |
|----------|--------|-------|
| Web (Chrome) | READY | No native dependencies in Stage 1 |
| Windows | READY | Keyboard shortcuts via Module K |
| macOS | READY | Similar to Windows |
| Android | PARTIAL | BT pedal needs testing |
| iOS | PARTIAL | BT pedal needs testing |

## 8. Recommendation

**Immediate next step**: Stage 2 (Score Image Restoration) can proceed independently in Python+OpenCV since it produces image files, not Flutter UI. The Python engine will later be wrapped as a native FFI module for Flutter.
