import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// En producción (Docker/Nginx), las peticiones van por el mismo origen
/// vía proxy reverso (/api/ → backend:8000/).
/// En desarrollo local, apunta directo al backend.
String _resolveBaseUrl() {
  if (kReleaseMode) {
    // En release, Nginx sirve el frontend y hace proxy de /api/
    return '/api';
  }
  if (kIsWeb) {
    // En desarrollo web, usar el host actual (útil para accesos desde móvil u otra IP)
    return 'http://${Uri.base.host}:8000';
  }
  return 'http://localhost:8000';
}

final String baseUrl = _resolveBaseUrl();

class ApiClient extends GetConnect {
  static ApiClient get to => Get.find();

  @override
  void onInit() {
    httpClient.baseUrl = baseUrl;
    httpClient.timeout = const Duration(seconds: 60);
    httpClient.defaultContentType = 'application/json';

    // Adjuntar token JWT en cada request (sin sobreescribir content-type de FormData)
    httpClient.addRequestModifier<dynamic>((request) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      // No forzar content-type en multipart
      if (request.headers['content-type']?.contains('multipart') == true) {
        request.headers.remove('content-type');
      }
      // Eliminar Content-Length para evitar el error "Refused to set unsafe header" en navegadores
      request.headers.remove('content-length');
      request.headers.remove('Content-Length');
      
      return request;
    });

    // Auto-refresh si recibe 401
    httpClient.addResponseModifier((request, response) async {
      if (response.statusCode == 401) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          request.headers['Authorization'] = 'Bearer $token';
          return await httpClient.request(
            request.url.toString(),
            request.method,
            body: request.bodyBytes,
            headers: request.headers,
          );
        }
      }
      return response;
    });

    super.onInit();
  }

  Future<bool> _tryRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return false;

      final response = await post(
        '$baseUrl/auth/refresh',
        {'refresh_token': refreshToken},
      );
      if (response.isOk) {
        await prefs.setString('access_token', response.body['access_token']);
        return true;
      }
      return false;
    } catch (_) {
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      return false;
    }
  }
}
