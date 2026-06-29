// Implementación vacía para plataformas no-web (móvil/desktop).
// En esos targets el token se guarda en Keystore/Keychain vía
// FlutterSecureStorage, así que estas funciones nunca se usan.
String? webSecureGet(String key) => null;
void webSecureSet(String key, String value) {}
void webSecureDel(String key) {}
