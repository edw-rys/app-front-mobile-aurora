import 'dart:io';
import 'package:dio/dio.dart';

/// Centralized utility to map DioExceptions to user-friendly messages.
class DioExceptionHandler {
  DioExceptionHandler._();

  /// Map common DioException scenarios to localized strings.
  static String mapToString(dynamic e) {
    if (e is! DioException) {
      return e.toString().replaceAll('Exception: ', '');
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tiempo de espera agotado. Reintente.';

      case DioExceptionType.connectionError:
        // This covers "Failed host lookup" and SocketExceptions
        if (e.error is SocketException) {
          final se = e.error as SocketException;
          // OS Error 7 or 110 usually mean unreachable/no-internet
          if (se.osError?.errorCode == 7 || se.osError?.errorCode == 110 || se.message.contains('Failed host lookup')) {
            return 'Sin conexión a internet';
          }
        }
        return 'Servicio no disponible';

      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final data = e.response?.data;
        
        // If server sent a specific message, priority #1
        if (data is Map && data.containsKey('message')) {
          return data['message'].toString();
        }

        if (status != null) {
          if (status >= 500) return 'Servicio no disponible (Error $status)';
          if (status == 401) return 'Sesión expirada o no autorizada';
          if (status == 403) return 'Acceso denegado';
          if (status == 404) return 'Recurso no encontrado';
        }
        return 'Error del servidor (Código $status)';

      case DioExceptionType.cancel:
        return 'Solicitud cancelada';

      default:
        // Fallback for unknown DioExceptionType
        if (e.error is SocketException) {
          return 'Sin conexión a internet';
        }
        return 'Error de red inesperado';
    }
  }
}
