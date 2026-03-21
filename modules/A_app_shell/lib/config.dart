// Note: kDebugMode is provided by Flutter's foundation.dart

/// Build flavor
enum BuildFlavor {
  dev,
  prod,
}

/// Current build flavor
const BuildFlavor buildFlavor = String.fromEnvironment('FLAVOR') == 'dev'
    ? BuildFlavor.dev
    : BuildFlavor.prod;

/// Whether to enable debug mode (only in dev flavor)
const bool enableDebugMode = buildFlavor == BuildFlavor.dev;

/// Whether to enable comparison feature (Module C)
const bool enableComparison = true;

/// Whether to enable external device support (Module K)
const bool enableExternalDevice = true;

/// Whether to enable OMR feature (Module E)
const bool enableOMR = false; // Stage 1: disabled

/// App version
const String appVersion = '1.0.0';

/// App name
const String appName = 'SmartScore';

/// Performance target thresholds (in milliseconds)
class PerformanceTargets {
  /// Cold startup target
  static const int coldStartupMs = 2000;

  /// Route navigation target
  static const int routeNavigationMs = 150;

  /// Page render target
  static const int pageRenderMs = 100;

  /// Hit test target
  static const int hitTestMs = 10;

  /// Device action latency target
  static const int deviceActionMs = 100;

  /// Library query target
  static const int libraryQueryMs = 100;
}

/// Memory limits (in MB)
class MemoryLimits {
  /// Baseline memory usage
  static const int baseline = 200;

  /// Peak memory usage
  static const int peak = 500;
}
