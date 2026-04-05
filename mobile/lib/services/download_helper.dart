/// Platform-agnostic download entry-point.
/// On web: triggers a browser file download.
/// On other platforms: no-op (caller should offer a share/save dialog instead).
export 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';
