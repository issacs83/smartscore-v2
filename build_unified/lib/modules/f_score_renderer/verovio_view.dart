/// Conditional export: web implementation or non-web stub.
///
/// Score viewer screens import this file; the compiler selects the
/// correct implementation based on the target platform.
export 'verovio_view_stub.dart'
    if (dart.library.html) 'verovio_view_web.dart';
