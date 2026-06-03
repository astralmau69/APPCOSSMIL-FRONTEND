import 'dart:js_interop';

@JS('localStorage.getItem')
external JSString? _get(JSString key);

@JS('localStorage.setItem')
external void _set(JSString key, JSString value);

@JS('localStorage.removeItem')
external void _del(JSString key);

@JS('localStorage.clear')
external void _clear();

String? webLsGet(String key) => _get(key.toJS)?.toDart;
void webLsSet(String key, String value) => _set(key.toJS, value.toJS);
void webLsDel(String key) => _del(key.toJS);
void webLsClear() => _clear();
