import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../core/api/api_client.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/widgets/app_shell.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _saving = false;
  bool _uploading = false;
  bool _showCurrentPw = false;
  bool _showNewPw = false;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentPwCtrl.text;
    final newPw = _newPwCtrl.text;
    final confirm = _confirmPwCtrl.text;

    if (current.isEmpty || newPw.isEmpty) {
      Get.snackbar('Error', 'Completa todos los campos',
          backgroundColor: const Color(0xFFE53935), colorText: Colors.white);
      return;
    }
    if (newPw != confirm) {
      Get.snackbar('Error', 'Las contraseñas no coinciden',
          backgroundColor: const Color(0xFFE53935), colorText: Colors.white);
      return;
    }
    if (newPw.length < 6) {
      Get.snackbar('Error', 'La nueva contraseña debe tener al menos 6 caracteres',
          backgroundColor: const Color(0xFFE53935), colorText: Colors.white);
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await ApiClient.to.put('/auth/profile', {
        'current_password': current,
        'new_password': newPw,
      });
      if (res.isOk) {
        _currentPwCtrl.clear();
        _newPwCtrl.clear();
        _confirmPwCtrl.clear();
        Get.snackbar('Guardado', 'Contraseña actualizada',
            backgroundColor: const Color(0xFF4CAF50), colorText: Colors.white);
      } else {
        final detail = res.body?['detail'] ?? 'Error al actualizar';
        Get.snackbar('Error', detail.toString(),
            backgroundColor: const Color(0xFFE53935), colorText: Colors.white);
      }
    } catch (_) {
      Get.snackbar('Error', 'Error de conexión',
          backgroundColor: const Color(0xFFE53935), colorText: Colors.white);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;

    setState(() => _uploading = true);
    try {
      final file = result.files.first;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final uri = Uri.parse('$baseUrl/auth/profile/avatar');

      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));

      final streamed = await request.send();
      if (streamed.statusCode == 200) {
        await AuthController.to.tryAutoLogin();
        setState(() {});
        Get.snackbar('Guardado', 'Foto de perfil actualizada',
            backgroundColor: const Color(0xFF4CAF50), colorText: Colors.white);
      } else {
        Get.snackbar('Error', 'No se pudo subir la imagen',
            backgroundColor: const Color(0xFFE53935), colorText: Colors.white);
      }
    } catch (_) {
      Get.snackbar('Error', 'Error de conexión',
          backgroundColor: const Color(0xFFE53935), colorText: Colors.white);
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Mi perfil',
      child: Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(32),
          child: Obx(() {
            final user = AuthController.to.user.value;
            if (user == null) {
              return const Text('No autenticado', style: TextStyle(color: Colors.white54));
            }

            final avatarUrl = user.avatarFileName != null
                ? '$baseUrl/auth/profile/avatar/${user.avatarFileName}'
                : null;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 40, color: Colors.white),
                              )
                            : null,
                      ),
                      GestureDetector(
                        onTap: _uploading ? null : _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF),
                            shape: BoxShape.circle,
                          ),
                          child: _uploading
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Info de solo lectura
                  _infoRow('Nombre', user.name),
                  const SizedBox(height: 12),
                  _infoRow('Correo', user.email),
                  const SizedBox(height: 12),
                  _infoRow('Rol', user.role == 'admin' ? 'Administrador' : 'QA'),
                  const SizedBox(height: 32),

                  // Cambiar contraseña
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Cambiar contraseña',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),
                  _pwField(_currentPwCtrl, 'Contraseña actual', _showCurrentPw, (v) {
                    setState(() => _showCurrentPw = v);
                  }),
                  const SizedBox(height: 12),
                  _pwField(_newPwCtrl, 'Nueva contraseña', _showNewPw, (v) {
                    setState(() => _showNewPw = v);
                  }),
                  const SizedBox(height: 12),
                  _pwField(_confirmPwCtrl, 'Confirmar nueva contraseña', false, null),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _saving ? null : _changePassword,
                      child: Text(_saving ? 'Guardando...' : 'Actualizar contraseña'),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _pwField(TextEditingController ctrl, String label, bool visible, void Function(bool)? onToggle) {
    return TextFormField(
      controller: ctrl,
      obscureText: !visible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF))),
        filled: true,
        fillColor: const Color(0xFF2A2A3E),
        suffixIcon: onToggle != null
            ? IconButton(
                icon: Icon(visible ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                onPressed: () => onToggle(!visible),
              )
            : null,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }
}
