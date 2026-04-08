import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/api/api_client.dart';
import 'core/api/router.dart';
import 'core/providers/auth_controller.dart';
import 'features/ai_chat/ai_chat_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar dependencias antes de correr la app
  Get.put(ApiClient(), permanent: true);
  final auth = Get.put(AuthController(), permanent: true);
  Get.put(AiChatController(), permanent: true);

  // Esperar a que el auto-login termine antes de decidir la ruta
  await auth.waitUntilReady();

  runApp(const QAPortalApp());
}

class QAPortalApp extends StatelessWidget {
  const QAPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.to;
    final initialRoute = auth.isAuthenticated ? '/projects' : '/login';

    return GetMaterialApp(
      title: 'QA Portal',
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      getPages: AppPages.routes,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
    );
  }
}
