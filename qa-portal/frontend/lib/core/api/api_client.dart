import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

/// En producción (Docker/Nginx), las peticiones van por el mismo origen
/// vía proxy reverso (/api/ → backend:8000/).
/// En desarrollo local, apunta directo al backend.
String _resolveBaseUrl() {
  if (kReleaseMode) {
    // En release, Nginx sirve el frontend y hace proxy de /api/
    return '/api';
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
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      // No forzar content-type en multipart
      if (request.headers['content-type']?.contains('multipart') == true) {
        request.headers.remove('content-type');
      }
      return request;
    });

    // Auto-refresh si recibe 401
    httpClient.addResponseModifier((request, response) async {
      if (response.statusCode == 401) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          final token = await _storage.read(key: 'access_token');
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
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await post(
        '$baseUrl/auth/refresh',
        {'refresh_token': refreshToken},
      );
      if (response.isOk) {
        await _storage.write(key: 'access_token', value: response.body['access_token']);
        return true;
      }
      return false;
    } catch (_) {
      await _storage.deleteAll();
      return false;
    }
  }
}
