/// Platform-abstract audio capture interface.
///
/// Web: Uses Web Audio API via JS interop (audio_capture_web.dart)
/// Native: Uses flutter_sound or record package (audio_capture_stub.dart for now)
export 'audio_capture_stub.dart'
    if (dart.library.html) 'audio_capture_web.dart';
