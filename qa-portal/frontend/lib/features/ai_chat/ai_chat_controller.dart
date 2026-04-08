import 'package:get/get.dart';
import '../../core/api/api_client.dart';
import '../../core/models/chat_message.dart';
import '../execution/execution_controller.dart';
import '../bugs/bugs_controller.dart';
import '../projects/projects_controller.dart';

class AiChatController extends GetxController {
  static AiChatController get to => Get.find();

  final RxBool isOpen = false.obs;
  final RxBool isLoading = false.obs;
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;

  void toggle() => isOpen.value = !isOpen.value;

  void clearChat() => messages.clear();

  Map<String, dynamic> _detectContext() {
    final route = Get.currentRoute;
    String contextType = 'general';
    Map<String, dynamic>? contextData;

    if (route.startsWith('/execution/run')) {
      contextType = 'execution';
      contextData = _getExecutionContext() ?? {};
      contextData['pantalla'] =
          'Ejecucion de pruebas — panel dividido: izquierda lista de test cases agrupados por modulo con indicador de estado, derecha detalle del test case seleccionado con pasos, asignacion de QA, notas, botones de estado (Paso/Fallo/Bloqueado/No Aplica), capturas de pantalla y registro de bugs';
    } else if (route.startsWith('/execution/dashboard')) {
      contextType = 'execution';
      contextData = _getExecutionDashboardContext() ?? {};
      contextData['pantalla'] =
          'Dashboard de ejecucion — conteo por estado, progreso por modulo y por QA, listado de bugs de la sesion';
    } else if (route.startsWith('/executions')) {
      contextType = 'execution';
      contextData = {
        'pantalla':
            'Lista de sesiones de ejecucion del proyecto — crear sesiones, ver progreso, continuar o finalizar sesiones'
      };
    } else if (route.startsWith('/bug')) {
      contextType = 'bug';
      contextData = _getBugContext() ?? {};
      contextData['pantalla'] =
          'Gestion de bugs — lista con filtros por severidad, estado, modulo y QA. Crear y editar bugs con asistencia de IA';
    } else if (route.startsWith('/modules/detail')) {
      contextType = 'test_case';
      contextData = _getTestCaseContext() ?? {};
      contextData['pantalla'] =
          'Detalle de modulo — lista de test cases con opciones de crear, editar, eliminar, duplicar y reordenar';
    } else if (route.startsWith('/test-case')) {
      contextType = 'test_case';
      contextData = _getTestCaseContext() ?? {};
      contextData['pantalla'] =
          'Formulario de test case — edicion de titulo, precondiciones, postcondiciones y pasos (accion, datos de prueba, resultado esperado)';
    } else if (route.startsWith('/reports')) {
      contextType = 'sonar_report';
      contextData = {
        'pantalla':
            'Reportes — generacion de PDFs: pruebas manuales, SonarQube con analisis IA, hoja de posteo GitHub, pruebas automatizadas QEngine'
      };
    } else if (route.startsWith('/projects/detail')) {
      contextType = 'test_case';
      contextData = _getProjectContext() ?? {};
      contextData['pantalla'] =
          'Detalle del proyecto — lista de modulos con opciones CRUD. Acceso a sesiones de ejecucion';
    } else if (route.startsWith('/projects')) {
      contextType = 'general';
      contextData = {
        'pantalla':
            'Lista de proyectos — muestra todos los proyectos de QA con su estado, permite crear nuevos'
      };
    } else if (route.startsWith('/profile')) {
      contextType = 'general';
      contextData = {
        'pantalla':
            'Perfil de usuario — informacion del usuario, actualizar correo y foto de perfil'
      };
    }

    return {
      'context_type': contextType,
      if (contextData != null) 'context_data': contextData,
    };
  }

  Map<String, dynamic>? _getExecutionContext() {
    try {
      final ctrl = Get.find<ExecutionController>();
      final exec = ctrl.currentExecution.value;
      final selected = ctrl.selectedResult.value;

      final data = <String, dynamic>{};
      if (exec != null) {
        data['sesion'] = exec.name;
        data['version'] = exec.version ?? '';
        data['ambiente'] = exec.environment;
      }
      if (selected != null) {
        final tc = selected.testCase;
        if (tc != null) {
          data['test_case'] = tc['title'] ?? '';
          data['modulo'] = tc['module_name'] ?? '';
          data['precondiciones'] = tc['preconditions'] ?? '';
          final steps = tc['steps'] as List<dynamic>? ?? [];
          if (steps.isNotEmpty) {
            data['pasos'] = steps
                .take(10)
                .map((s) {
                  final step = s as Map<String, dynamic>;
                  return '${step['order']}. ${step['action']} -> ${step['expected_result']}';
                })
                .join('\n');
          }
        }
        data['estado_actual'] = selected.status;
        if (selected.notes != null && selected.notes!.isNotEmpty) {
          data['notas'] = selected.notes!;
        }
        if (selected.assignedTo != null) {
          data['asignado_a'] = selected.assignedTo!;
        }
      }
      return data.isEmpty ? null : data;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _getExecutionDashboardContext() {
    try {
      final ctrl = Get.find<ExecutionController>();
      final dash = ctrl.dashboard;
      if (dash.isEmpty) return null;
      return {
        'total': dash['total'] ?? 0,
        'passed': dash['passed'] ?? 0,
        'failed': dash['failed'] ?? 0,
        'blocked': dash['blocked'] ?? 0,
        'pending': dash['pending'] ?? 0,
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _getBugContext() {
    try {
      final ctrl = Get.find<BugsController>();
      final bugs = ctrl.bugs;
      if (bugs.isEmpty) return null;

      final severityCounts = <String, int>{};
      final statusCounts = <String, int>{};
      for (final b in bugs) {
        final sev = b['severity']?.toString() ?? 'unknown';
        final st = b['status']?.toString() ?? 'unknown';
        severityCounts[sev] = (severityCounts[sev] ?? 0) + 1;
        statusCounts[st] = (statusCounts[st] ?? 0) + 1;
      }

      return {
        'total_bugs': bugs.length,
        'por_severidad': severityCounts.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', '),
        'por_estado': statusCounts.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', '),
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _getTestCaseContext() {
    try {
      final ctrl = Get.find<ProjectsController>();
      final cases = ctrl.testCases;
      if (cases.isEmpty) return null;

      return {
        'total_test_cases': cases.length,
        'casos': cases
            .take(5)
            .map((tc) => '${tc.title} (${tc.steps.length} pasos)')
            .join(', '),
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _getProjectContext() {
    try {
      final ctrl = Get.find<ProjectsController>();
      final mods = ctrl.modules;
      if (mods.isEmpty) return null;

      return {
        'total_modulos': mods.length,
        'modulos': mods.take(10).map((m) => m.name).join(', '),
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    messages.add(ChatMessage(role: 'user', content: text.trim()));
    isLoading.value = true;

    try {
      final context = _detectContext();
      final history = messages
          .where((m) => m != messages.last)
          .take(20)
          .map((m) => m.toJson())
          .toList();

      final response = await ApiClient.to.post('/ai/chat', {
        'message': text.trim(),
        ...context,
        'history': history,
      });

      if (response.isOk && response.body != null) {
        final reply = response.body['reply'] as String? ?? 'Sin respuesta';
        messages.add(ChatMessage(role: 'assistant', content: reply));
      } else {
        messages.add(ChatMessage(
          role: 'assistant',
          content: 'Error al obtener respuesta. Intenta de nuevo.',
        ));
      }
    } catch (e) {
      messages.add(ChatMessage(
        role: 'assistant',
        content: 'Error de conexion con el asistente.',
      ));
    } finally {
      isLoading.value = false;
    }
  }
}
