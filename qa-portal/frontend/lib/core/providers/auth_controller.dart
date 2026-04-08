import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../api/api_client.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  static const _storage = FlutterSecureStorage();

  final Rx<User?> user = Rx<User?>(null);
  final RxBool loading = false.obs;
  final RxBool authReady = false.obs;

  bool get isAuthenticated => user.value != null;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    await tryAutoLogin();
    authReady.value = true;
  }

  Future<void> tryAutoLogin() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;
    try {
      final res = await ApiClient.to.get('/auth/me');
      if (res.isOk) {
        user.value = User.fromJson(res.body);
        return;
      }
      // Token expirado — intentar refresh
      if (res.statusCode == 401) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          final retry = await ApiClient.to.get('/auth/me');
          if (retry.isOk) {
            user.value = User.fromJson(retry.body);
            return;
          }
        }
      }
      // Si nada funcionó, limpiar
      await _storage.deleteAll();
    } catch (_) {
      // No borrar tokens por error de red — puede ser temporal
    }
  }

  Future<bool> _tryRefresh() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;
      final res = await ApiClient.to.post(
        '${baseUrl}/auth/refresh',
        {'refresh_token': refreshToken},
      );
      if (res.isOk) {
        await _storage.write(key: 'access_token', value: res.body['access_token']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> login(String email, String password) async {
    loading.value = true;
    try {
      final res = await ApiClient.to.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (!res.isOk) {
        return res.body['detail'] ?? 'Error al iniciar sesión';
      }

      await _storage.write(key: 'access_token', value: res.body['access_token']);
      await _storage.write(key: 'refresh_token', value: res.body['refresh_token']);

      final me = await ApiClient.to.get('/auth/me');
      if (me.isOk) user.value = User.fromJson(me.body);

      return null;
    } catch (_) {
      return 'Error de conexión. Verifica que el servidor esté activo.';
    } finally {
      loading.value = false;
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken != null) {
      try {
        await ApiClient.to.post('/auth/logout', {'refresh_token': refreshToken});
      } catch (_) {}
    }
    await _storage.deleteAll();
    user.value = null;
    Get.offAllNamed('/login');
  }
}
