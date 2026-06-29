import 'dart:js_interop';

/// Almacenamiento web endurecido para datos sensibles (tokens).
///
/// A diferencia de `localStorage`, aquí la copia primaria vive SOLO en la
/// memoria de la pestaña (heap de JS): no aparece en F12 → Application →
/// Local Storage y no sobrevive al cierre del navegador.
///
/// Se mantiene un respaldo en `sessionStorage` para que un simple recargado
/// (F5) no obligue a re-iniciar sesión. `sessionStorage`:
///   - se borra automáticamente al cerrar la pestaña/navegador,
///   - es independiente por pestaña (no se comparte como localStorage).
///
/// Para máxima ocultación (que el token NO aparezca tampoco en Application →
/// Session Storage) poner [_persistAcrossReload] en `false`: el token vivirá
/// solo en memoria y un F5 cerrará la sesión.
const bool _persistAcrossReload = true;

/// Copia primaria en memoria. Es la fuente de verdad mientras la pestaña vive.
final Map<String, String> _memCache = {};

@JS('sessionStorage.getItem')
external JSString? _ssGet(JSString key);

@JS('sessionStorage.setItem')
external void _ssSet(JSString key, JSString value);

@JS('sessionStorage.removeItem')
external void _ssDel(JSString key);

String? webSecureGet(String key) {
  final mem = _memCache[key];
  if (mem != null) return mem;
  if (!_persistAcrossReload) return null;
  // Tras un F5 la memoria se vacía: recuperamos del respaldo de sesión.
  final ss = _ssGet(key.toJS)?.toDart;
  if (ss != null) _memCache[key] = ss;
  return ss;
}

void webSecureSet(String key, String value) {
  _memCache[key] = value;
  if (_persistAcrossReload) _ssSet(key.toJS, value.toJS);
}

void webSecureDel(String key) {
  _memCache.remove(key);
  _ssDel(key.toJS);
}
