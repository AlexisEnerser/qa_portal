import 'dart:async';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../api/api_client.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final Rx<User?> user = Rx<User?>(null);
  final RxBool loading = false.obs;
  final RxBool authReady = false.obs;

  bool get isAuthenticated => user.value != null;

  /// Espera a que el auto-login termine. Se usa en main() antes de runApp.
  Future<void> waitUntilReady() async {
    if (authReady.value) return;
    final completer = Completer<void>();
    final worker = ever(authReady, (ready) {
      if (ready && !completer.isCompleted) completer.complete();
    });
    if (authReady.value && !completer.isCompleted) completer.complete();
    await completer.future;
    worker.dispose();
  }

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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
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
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
    } catch (_) {
      // No borrar tokens por error de red — puede ser temporal
    }
  }

  Future<bool> _tryRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return false;
      final res = await ApiClient.to.post(
        '/auth/refresh',
        {'refresh_token': refreshToken},
      );
      if (res.isOk) {
        await prefs.setString('access_token', res.body['access_token']);
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
        if (res.body == null) {
          return 'Error de conexión con el servidor.';
        }
        if (res.body is Map) {
          return res.body['detail'] ?? 'Error al iniciar sesión';
        }
        return 'Error al iniciar sesión';
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', res.body['access_token']);
      await prefs.setString('refresh_token', res.body['refresh_token']);

      final me = await ApiClient.to.get('/auth/me');
      if (me.isOk) user.value = User.fromJson(me.body);

      return null;
    } catch (e) {
      return e.toString();
      //return 'Error de conexión. Verifica que el servidor esté activo.';
    } finally {
      loading.value = false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken != null) {
      try {
        await ApiClient.to.post('/auth/logout', {'refresh_token': refreshToken});
      } catch (_) {}
    }
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    user.value = null;
    Get.offAllNamed('/login');
  }
}
