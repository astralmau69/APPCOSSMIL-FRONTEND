import 'dart:io';
import 'dart:async';

/// Define contextos específicos donde ocurren los errores
/// para proporcionar mensajes más precisos.
enum ErrorContext {
  login,
  verificarVersion,
  cargarRegionales,
  cargarEspecialidades,
  cargarAgenda,
  crearCita,
  cancelarCita,
  cargarHistorial,
  descargarPdf,
  cambiarPassword,
  cargarPerfil,
  general,
}

/// Clase centralizada para el manejo y traducción de excepciones técnicas
/// en mensajes humanos, útiles y amigables para la UI.
class ErrorMapper {
  /// true si [error] representa una caída de red/conectividad (no un error de
  /// negocio). La UI lo usa para decidir entre mostrar la caché offline
  /// ("Modo sin conexión") y mostrar el estado de error con "Reintentar".
  ///
  /// Cubre las excepciones crudas (SocketException/TimeoutException) Y el mensaje
  /// con el que [ApiClient] envuelve los fallos de red ("No se pudo conectar al
  /// servidor.", statusCode 0), que de otro modo no se detectaría por texto.
  static bool isOffline(dynamic error) {
    if (error == null) return false;
    if (error is SocketException || error is TimeoutException) return true;
    final s = error.toString().toLowerCase();
    return s.contains('socket') ||
        s.contains('internet') ||
        s.contains('network') ||
        s.contains('timeout') ||
        s.contains('failed host lookup') ||
        s.contains('connection') ||
        s.contains('no se pudo conectar') ||
        s.contains('sin conexión') ||
        s.contains('sin conexion');
  }

  static String message(
    dynamic error, {
    ErrorContext context = ErrorContext.general,
  }) {
    if (error == null)
      return 'Ocurrió un error inesperado. Intenta nuevamente.';

    final msg = error.toString();
    final lowerMsg = msg.toLowerCase();

    // 1. Errores de Red y Timeout
    if (error is SocketException ||
        lowerMsg.contains('socket') ||
        lowerMsg.contains('internet') ||
        lowerMsg.contains('network')) {
      return 'No tienes conexión a internet. Verifica tu red e inténtalo otra vez.';
    }
    if (error is TimeoutException || lowerMsg.contains('timeout')) {
      return 'La solicitud tardó demasiado. Revisa tu conexión a internet e inténtalo más tarde.';
    }

    // 2. Errores HTTP Crudos (Mapeo por códigos)
    if (_containsStatusCode(lowerMsg, 400)) {
      return 'Los datos enviados no son válidos. Por favor, verifica e intenta de nuevo.';
    }
    if (_containsStatusCode(lowerMsg, 401) ||
        lowerMsg.contains('unauthorized') ||
        lowerMsg.contains('unauthenticated')) {
      return 'Tu sesión expiró o no tienes acceso. Por favor, vuelve a iniciar sesión.';
    }
    if (_containsStatusCode(lowerMsg, 403)) {
      return 'No tienes permisos para realizar esta acción.';
    }
    if (_containsStatusCode(lowerMsg, 404)) {
      return 'No se encontró la información solicitada en el sistema.';
    }
    if (_containsStatusCode(lowerMsg, 409)) {
      return 'Esta acción ya fue realizada o hay información duplicada.';
    }
    if (_containsStatusCode(lowerMsg, 413)) {
      return 'El archivo o la información enviada es demasiado grande.';
    }
    if (_containsStatusCode(lowerMsg, 422)) {
      return 'La información que ingresaste no cumple con los requisitos del sistema.';
    }
    if (_containsStatusCode(lowerMsg, 429)) {
      return 'Estás intentando hacer esto muy rápido. Espera un momento y vuelve a intentar.';
    }
    if (_containsStatusCode(lowerMsg, 500) ||
        _containsStatusCode(lowerMsg, 502) ||
        _containsStatusCode(lowerMsg, 503) ||
        _containsStatusCode(lowerMsg, 504)) {
      return 'Nuestros servidores no están disponibles en este momento. Intenta más tarde.';
    }

    // 3. Limpieza de mensajes técnicos (DioExceptions, etc.)
    if (lowerMsg.contains('dioexception') ||
        lowerMsg.contains('bad response') ||
        lowerMsg.contains('xmlhttprequest')) {
      return 'Hubo un problema de conexión con el servidor. Intenta nuevamente.';
    }

    // 4. Mapeo específico por contexto y mensajes del backend recuperados
    // (Si el backend manda un mensaje útil sin códigos raros, preferimos adaptarlo)
    final cleanedMsg = msg.replaceFirst('Exception:', '').trim();

    // Filtros de limpieza para mensajes del backend
    if (cleanedMsg.isNotEmpty &&
        !cleanedMsg.contains('{') &&
        !cleanedMsg.contains('<') &&
        cleanedMsg.length < 80) {
      if (lowerMsg.contains('inválido') ||
          lowerMsg.contains('incorrecto') ||
          lowerMsg.contains('credenciales')) {
        return cleanedMsg; // Seguro para mostrar (usualmente viene de Spring /auth)
      }
    }

    // Contextos
    switch (context) {
      case ErrorContext.login:
        return 'No pudimos iniciar sesión. Verifica tus datos o tu conexión e inténtalo nuevamente.';
      case ErrorContext.verificarVersion:
        return 'No pudimos verificar la versión de la app. Revisa tu internet e ingresa nuevamente.';
      case ErrorContext.cargarRegionales:
        return 'No pudimos cargar los establecimientos disponibles. Intenta nuevamente.';
      case ErrorContext.cargarEspecialidades:
        return 'No pudimos cargar las especialidades. Es posible que no hayan horarios habilitados.';
      case ErrorContext.cargarAgenda:
        return 'No hay médicos con horas disponibles en este momento o hubo un problema al cargar la agenda.';
      case ErrorContext.crearCita:
        return 'No se pudo guardar la reserva en el sistema. Es probable que la hora ya haya sido tomada.';
      case ErrorContext.cancelarCita:
        return 'No pudimos cancelar la reserva. Intenta nuevamente más tarde.';
      case ErrorContext.cargarHistorial:
        return 'No pudimos cargar tu historial de reservas. Intenta deslizar hacia abajo para refrescar.';
      case ErrorContext.descargarPdf:
        return 'No pudimos descargar el documento de tu reserva. Intenta nuevamente.';
      case ErrorContext.cambiarPassword:
        return 'No pudimos actualizar tus datos. Verifica la información e intenta nuevamente.';
      case ErrorContext.cargarPerfil:
        return 'No pudimos cargar los datos de tu perfil completamente. Intenta nuevamente más tarde.';
      case ErrorContext.general:
        return 'No pudimos completar esta acción. Intenta nuevamente en unos momentos.';
    }
  }

  static bool _containsStatusCode(String lowerMsg, int code) {
    return lowerMsg.contains('$code') &&
        (lowerMsg.contains('status code') ||
            lowerMsg.contains('error') ||
            lowerMsg.contains('http'));
  }
}
