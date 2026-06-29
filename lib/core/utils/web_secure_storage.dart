// Selector de implementación por plataforma:
//   - Web   → web_secure_storage_web.dart  (memoria + sessionStorage)
//   - Resto → web_secure_storage_stub.dart (no-op; usa Keystore/Keychain)
export 'web_secure_storage_stub.dart'
    if (dart.library.js_interop) 'web_secure_storage_web.dart';
