import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/api/api_client.dart';
import 'core/api/router.dart';
import 'core/providers/auth_controller.dart';
import 'features/ai_chat/ai_chat_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QAPortalApp());
}

class QAPortalApp extends StatelessWidget {
  const QAPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'QA Portal',
      debugShowCheckedModeBanner: false,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      initialBinding: BindingsBuilder(() {
        Get.put(ApiClient(), permanent: true);
        Get.put(AuthController(), permanent: true);
        Get.put(AiChatController(), permanent: true);
      }),
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
