import 'package:get/get.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/project.dart';

class ProjectsController extends GetxController {
  static ProjectsController get to => Get.find();

  RxList<AppProject> projects = <AppProject>[].obs;
  RxBool loading = false.obs;
  RxString error = ''.obs;

  RxList<AppModule> modules = <AppModule>[].obs;
  RxList<TestCase> testCases = <TestCase>[].obs;
  RxString currentModuleId = ''.obs;

  RxBool aiLoading = false.obs;
  RxString aiError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadProjects();
  }

  // ─── Projects ─────────────────────────────────────────────────────────────

  Future<void> loadProjects() async {
    loading.value = true;
    error.value = '';
    try {
      final response = await ApiClient.to.get('/projects');
      if (response.isOk && response.body != null) {
        final List<dynamic> data = response.body as List<dynamic>;
        projects.value = data.map((e) => AppProject.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        error.value = 'Error al cargar proyectos';
      }
    } catch (e) {
      error.value = 'Error inesperado: $e';
    } finally {
      loading.value = false;
    }
  }

  Future<bool> createProject(String name, String description) async {
    try {
      final response = await ApiClient.to.post(
        '/projects',
        {'name': name, 'description': description},
      );
      if (response.isOk) {
        await loadProjects();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateProject(String id, String name, String description) async {
    try {
      final response = await ApiClient.to.put(
        '/projects/$id',
        {'name': name, 'description': description},
      );
      if (response.isOk) {
        await loadProjects();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteProject(String id) async {
    try {
      final response = await ApiClient.to.delete('/projects/$id');
      if (response.isOk) {
        await loadProjects();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── Modules ──────────────────────────────────────────────────────────────

  Future<void> loadModules(String projectId) async {
    loading.value = true;
    error.value = '';
    try {
      final response = await ApiClient.to.get('/projects/$projectId/modules');
      if (response.isOk && response.body != null) {
        final List<dynamic> data = response.body as List<dynamic>;
        modules.value = data.map((e) => AppModule.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        error.value = 'Error al cargar módulos';
      }
    } catch (e) {
      error.value = 'Error inesperado: $e';
    } finally {
      loading.value = false;
    }
  }

  Future<bool> createModule(String projectId, String name, String description) async {
    try {
      final response = await ApiClient.to.post(
        '/projects/$projectId/modules',
        {'name': name, 'description': description},
      );
      if (response.isOk) {
        await loadModules(projectId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateModule(
    String projectId,
    String moduleId,
    String name,
    String description,
  ) async {
    try {
      final response = await ApiClient.to.put(
        '/projects/$projectId/modules/$moduleId',
        {'name': name, 'description': description},
      );
      if (response.isOk) {
        await loadModules(projectId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteModule(String projectId, String moduleId) async {
    try {
      final response = await ApiClient.to.delete(
        '/projects/$projectId/modules/$moduleId',
      );
      if (response.isOk) {
        await loadModules(projectId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── Test Cases ───────────────────────────────────────────────────────────

  Future<void> loadTestCases(String moduleId) async {
    currentModuleId.value = moduleId;
    loading.value = true;
    error.value = '';
    try {
      final response = await ApiClient.to.get('/qa/modules/$moduleId/test-cases');
      if (response.isOk && response.body != null) {
        final List<dynamic> data = response.body as List<dynamic>;
        testCases.value = data.map((e) => TestCase.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        error.value = 'Error al cargar casos de prueba';
      }
    } catch (e) {
      error.value = 'Error inesperado: $e';
    } finally {
      loading.value = false;
    }
  }

  Future<bool> deleteTestCase(String testCaseId) async {
    try {
      final response = await ApiClient.to.delete('/qa/test-cases/$testCaseId');
      if (response.isOk) {
        if (currentModuleId.value.isNotEmpty) {
          await loadTestCases(currentModuleId.value);
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> duplicateTestCase(String testCaseId) async {
    try {
      final response = await ApiClient.to.post(
        '/qa/test-cases/$testCaseId/duplicate',
        {},
      );
      if (response.isOk) {
        if (currentModuleId.value.isNotEmpty) {
          await loadTestCases(currentModuleId.value);
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> generateWithAI(
    String moduleId,
    String description,
  ) async {
    aiLoading.value = true;
    aiError.value = '';
    try {
      final response = await ApiClient.to.post(
        '/qa/modules/$moduleId/test-cases/generate',
        {'description': description},
      );
      if (response.isOk && response.body != null) {
        return response.body as Map<String, dynamic>;
      } else {
        aiError.value = 'Error al generar con IA';
        return null;
      }
    } catch (e) {
      aiError.value = 'Error inesperado: $e';
      return null;
    } finally {
      aiLoading.value = false;
    }
  }

  Future<bool> createTestCase(String moduleId, Map<String, dynamic> body) async {
    try {
      final response = await ApiClient.to.post(
        '/qa/modules/$moduleId/test-cases',
        body,
      );
      if (response.isOk) {
        await loadTestCases(moduleId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> reorderTestCases(String moduleId) async {
    final ids = testCases.map((tc) => tc.id).toList();
    try {
      await ApiClient.to.put(
        '/qa/modules/$moduleId/test-cases/reorder',
        ids,
      );
    } catch (_) {}
  }

  Future<bool> updateTestCase(String testCaseId, Map<String, dynamic> body) async {
    try {
      final dynamic steps = body['steps'];
      final caseBody = Map<String, dynamic>.from(body)..remove('steps');

      final caseResponse = await ApiClient.to.put(
        '/qa/test-cases/$testCaseId',
        caseBody,
      );
      if (!caseResponse.isOk) return false;

      if (steps != null) {
        final stepsResponse = await ApiClient.to.put(
          '/qa/test-cases/$testCaseId/steps',
          steps,
        );
        if (!stepsResponse.isOk) return false;
      }

      if (currentModuleId.value.isNotEmpty) {
        await loadTestCases(currentModuleId.value);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
