import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../core/api/api_client.dart';
import '../../core/models/execution.dart';

class ExecutionController extends GetxController {
  static ExecutionController get to => Get.find();

  // ── Executions list ────────────────────────────────────────────────────────
  RxList<TestExecutionSummary> executions = <TestExecutionSummary>[].obs;
  RxBool loading = false.obs;
  RxString error = ''.obs;
  RxString currentProjectId = ''.obs;

  Future<void> loadExecutions(String projectId) async {
    loading.value = true;
    error.value = '';
    currentProjectId.value = projectId;
    try {
      final response = await ApiClient.to.get('/qa/projects/$projectId/executions');
      if (response.isOk) {
        final List<dynamic> data = response.body as List<dynamic>;
        executions.value = data
            .map((e) => TestExecutionSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        error.value = 'Error al cargar sesiones';
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<bool> createExecution(
    String projectId,
    String name,
    String version,
    String environment, {
    List<String>? moduleIds,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'version': version,
        'environment': environment,
      };
      if (moduleIds != null && moduleIds.isNotEmpty) {
        body['module_ids'] = moduleIds;
      }
      final response = await ApiClient.to.post(
        '/qa/projects/$projectId/executions',
        body,
      );
      if (response.isOk) {
        await loadExecutions(projectId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> finishExecution(String executionId) async {
    try {
      final response =
          await ApiClient.to.post('/qa/executions/$executionId/finish', {});
      if (response.isOk) {
        await loadExecutions(currentProjectId.value);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteExecution(String executionId) async {
    try {
      final response =
          await ApiClient.to.delete('/qa/executions/$executionId');
      if (response.isOk || response.statusCode == 204) {
        await loadExecutions(currentProjectId.value);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Modules (for execution creation) ────────────────────────────────────────
  RxList<Map<String, dynamic>> projectModules = <Map<String, dynamic>>[].obs;

  Future<void> loadProjectModules(String projectId) async {
    try {
      final response = await ApiClient.to.get('/projects/$projectId/modules');
      if (response.isOk) {
        final List<dynamic> data = response.body as List<dynamic>;
        projectModules.value = data
            .map((m) => Map<String, dynamic>.from(m as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  // ── Execution run (split panel state) ─────────────────────────────────────
  Rx<TestExecution?> currentExecution = Rx<TestExecution?>(null);
  RxList<ExecutionResult> results = <ExecutionResult>[].obs;
  Rx<ExecutionResult?> selectedResult = Rx<ExecutionResult?>(null);

  Future<void> loadExecution(String executionId) async {
    loading.value = true;
    error.value = '';
    try {
      final execRes = await ApiClient.to.get('/qa/executions/$executionId');
      final resultsRes = await ApiClient.to.get('/qa/executions/$executionId/results');

      if (execRes.isOk) {
        currentExecution.value = TestExecution.fromJson(execRes.body as Map<String, dynamic>);
      } else {
        error.value = 'Error al cargar la ejecución';
        return;
      }

      if (resultsRes.isOk) {
        final List<dynamic> data = resultsRes.body as List<dynamic>;
        results.value = data
            .map((r) => ExecutionResult.fromJson(r as Map<String, dynamic>))
            .toList();
      } else {
        error.value = 'Error al cargar resultados';
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<bool> updateResult(
    String executionId,
    String resultId, {
    String? status,
    String? assignedTo,
    String? notes,
    String? route,
    int? durationSeconds,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (status != null) body['status'] = status;
      if (assignedTo != null) body['assigned_to'] = assignedTo;
      if (notes != null) body['notes'] = notes;
      if (route != null) body['route'] = route;
      if (durationSeconds != null) body['duration_seconds'] = durationSeconds;

      final response = await ApiClient.to.put(
        '/qa/executions/$executionId/results/$resultId',
        body,
      );
      if (response.isOk) {
        final updated =
            ExecutionResult.fromJson(response.body as Map<String, dynamic>);
        final idx = results.indexWhere((r) => r.id == resultId);
        if (idx != -1) {
          // Preservar test_case del original (el response no lo incluye)
          final original = results[idx];
          final merged = ExecutionResult(
            id: updated.id,
            executionId: updated.executionId,
            testCaseId: updated.testCaseId,
            assignedTo: updated.assignedTo,
            status: updated.status,
            notes: updated.notes,
            route: updated.route,
            executedAt: updated.executedAt,
            durationSeconds: updated.durationSeconds,
            testCase: original.testCase,
            screenshots: original.screenshots,
          );
          results[idx] = merged;
          results.refresh();
          if (selectedResult.value?.id == resultId) {
            selectedResult.value = merged;
          }
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void selectResult(ExecutionResult result) {
    selectedResult.value = result;
    // Always fetch fresh screenshots from API
    loadScreenshots(result.id);
  }

  // ── Screenshots ────────────────────────────────────────────────────────────
  RxList<Map<String, dynamic>> screenshots = <Map<String, dynamic>>[].obs;

  Future<void> loadScreenshots(String resultId) async {
    try {
      final response = await ApiClient.to.get('/qa/results/$resultId/screenshots');
      if (response.isOk) {
        final List<dynamic> data = response.body as List<dynamic>;
        screenshots.value = data
            .map((s) => Map<String, dynamic>.from(s as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  Future<bool> uploadScreenshot(
    String resultId,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final uri = Uri.parse('$baseUrl/qa/results/$resultId/screenshots');

      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(http.MultipartFile.fromBytes(
        'files',
        bytes,
        filename: fileName,
      ));

      final streamed = await request.send();
      if (streamed.statusCode == 201) {
        // Just reload screenshots, don't reload the entire execution
        await loadScreenshots(resultId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteScreenshot(String screenshotId) async {
    try {
      final response =
          await ApiClient.to.delete('/qa/screenshots/$screenshotId');
      if (response.isOk) {
        screenshots.removeWhere(
          (s) => s['id']?.toString() == screenshotId,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> reorderScreenshots(String resultId) async {
    final ids = screenshots.map((s) => s['id']?.toString() ?? '').toList();
    try {
      await ApiClient.to.put(
        '/qa/results/$resultId/screenshots/reorder',
        {'screenshot_ids': ids},
      );
    } catch (_) {}
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────
  RxMap<String, dynamic> dashboard = <String, dynamic>{}.obs;

  Future<void> loadDashboard(String executionId) async {
    loading.value = true;
    error.value = '';
    try {
      final response =
          await ApiClient.to.get('/qa/executions/$executionId/dashboard');
      if (response.isOk) {
        dashboard.value =
            Map<String, dynamic>.from(response.body as Map<String, dynamic>);
      } else {
        error.value = 'Error al cargar el dashboard';
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  // ── Users (for assignee dropdown) ─────────────────────────────────────────
  RxList<Map<String, dynamic>> qaUsers = <Map<String, dynamic>>[].obs;

  Future<void> loadUsers() async {
    try {
      final response = await ApiClient.to.get('/users/qa-team');
      if (response.isOk) {
        final List<dynamic> data = response.body as List<dynamic>;
        qaUsers.value = data
            .map((u) => Map<String, dynamic>.from(u as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  // ── PDF Versions ──────────────────────────────────────────────────────────
  RxList<Map<String, dynamic>> pdfVersions = <Map<String, dynamic>>[].obs;

  Future<void> loadPdfVersions(String executionId) async {
    try {
      final response = await ApiClient.to.get('/qa/executions/$executionId/pdf-versions');
      if (response.isOk) {
        final List<dynamic> data = response.body as List<dynamic>;
        pdfVersions.value = data
            .map((v) => Map<String, dynamic>.from(v as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  Future<String?> uploadPdf(String executionId, Uint8List pdfBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final uri = Uri.parse('$baseUrl/qa/executions/$executionId/pdf-upload');

      final request = http.Request('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Content-Type'] = 'application/pdf';
      request.bodyBytes = pdfBytes;

      final streamed = await request.send();
      if (streamed.statusCode == 200) {
        await loadPdfVersions(executionId);
        return null; // success
      }
      return 'Error al subir PDF';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> getPdfDownloadUrl(String executionId, String versionId) async {
    try {
      final response = await ApiClient.to.get(
        '/qa/executions/$executionId/pdf-versions/$versionId/download',
      );
      if (response.isOk) {
        return response.body['url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
