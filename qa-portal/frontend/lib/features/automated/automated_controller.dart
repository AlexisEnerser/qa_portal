import 'dart:async';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/models/automated.dart';
import 'automated_pdf_service.dart';

class AutomatedController extends GetxController {
  static AutomatedController get to => Get.find();

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Suites
  final RxList<AutomatedSuiteSummary> suites = <AutomatedSuiteSummary>[].obs;

  // Tests de una suite
  final RxList<AutomatedTestCaseModel> tests = <AutomatedTestCaseModel>[].obs;

  // Runs de una suite
  final RxList<AutomatedRunSummary> runs = <AutomatedRunSummary>[].obs;

  // Resultados de un run
  final RxList<AutomatedRunResult> results = <AutomatedRunResult>[].obs;

  // Estado de ejecución en tiempo real
  final Rx<RunStatusModel?> runStatus = Rx<RunStatusModel?>(null);
  Timer? _pollTimer;

  // Script generado por IA
  final RxString generatedScript = ''.obs;
  final RxBool isGenerating = false.obs;

  // ─── Suites ──────────────────────────────────────────────────────────

  Future<void> loadSuites(String projectId) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final resp = await ApiClient.to.get('/automated/suites?project_id=$projectId');
      if (resp.isOk) {
        final list = resp.body as List;
        suites.value = list
            .map((e) => AutomatedSuiteSummary.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else {
        errorMessage.value = 'Error al cargar suites';
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createSuite(String projectId, String name, String? description) async {
    try {
      final resp = await ApiClient.to.post('/automated/suites', {
        'project_id': projectId,
        'name': name,
        'description': description,
      });
      return resp.isOk;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteSuite(String suiteId) async {
    try {
      final resp = await ApiClient.to.delete('/automated/suites/$suiteId');
      return resp.isOk;
    } catch (_) {
      return false;
    }
  }

  // ─── Tests ───────────────────────────────────────────────────────────

  Future<void> loadTests(String suiteId) async {
    isLoading.value = true;
    try {
      final resp = await ApiClient.to.get('/automated/suites/$suiteId/tests');
      if (resp.isOk) {
        final list = resp.body as List;
        tests.value = list
            .map((e) => AutomatedTestCaseModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createTest(String suiteId, String name, String? description,
      String? scriptCode, String? targetUrl, String? sourceTestCaseId) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'description': description,
        'script_code': scriptCode,
        'target_url': targetUrl,
      };
      if (sourceTestCaseId != null) body['source_test_case_id'] = sourceTestCaseId;
      final resp = await ApiClient.to.post('/automated/suites/$suiteId/tests', body);
      return resp.isOk;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTest(String testId, Map<String, dynamic> data) async {
    try {
      final resp = await ApiClient.to.put('/automated/tests/$testId', data);
      return resp.isOk;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTest(String testId) async {
    try {
      final resp = await ApiClient.to.delete('/automated/tests/$testId');
      return resp.isOk;
    } catch (_) {
      return false;
    }
  }

  // ─── Clone from manual ──────────────────────────────────────────────

  Future<AutomatedTestCaseModel?> cloneFromManual(
      String suiteId, String sourceTestCaseId, String targetUrl) async {
    isGenerating.value = true;
    try {
      final resp = await ApiClient.to.post('/automated/tests/clone-from-manual', {
        'suite_id': suiteId,
        'source_test_case_id': sourceTestCaseId,
        'target_url': targetUrl,
      });
      if (resp.isOk) {
        return AutomatedTestCaseModel.fromJson(Map<String, dynamic>.from(resp.body as Map));
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      isGenerating.value = false;
    }
  }

  // ─── IA Script Generation ───────────────────────────────────────────

  Future<String?> generateScript(String description, String targetUrl) async {
    isGenerating.value = true;
    generatedScript.value = '';
    try {
      final resp = await ApiClient.to.post('/automated/generate-script', {
        'description': description,
        'target_url': targetUrl,
      });
      if (resp.isOk) {
        final code = resp.body['script_code'] as String;
        generatedScript.value = code;
        return code;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      isGenerating.value = false;
    }
  }

  Future<String?> refineScript(String currentScript, String instruction) async {
    isGenerating.value = true;
    try {
      final resp = await ApiClient.to.post('/automated/refine-script', {
        'current_script': currentScript,
        'instruction': instruction,
      });
      if (resp.isOk) {
        final code = resp.body['script_code'] as String;
        generatedScript.value = code;
        return code;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      isGenerating.value = false;
    }
  }

  // ─── Ejecución ──────────────────────────────────────────────────────

  Future<String?> startRun(String suiteId, {String? environment, String? version}) async {
    try {
      final resp = await ApiClient.to.post('/automated/suites/$suiteId/run', {
        'environment': environment,
        'version': version,
      });
      if (resp.isOk) {
        return resp.body['id'] as String;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void startPolling(String runId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _fetchRunStatus(runId);
      if (runStatus.value != null &&
          (runStatus.value!.status == 'completed' ||
           runStatus.value!.status == 'failed' ||
           runStatus.value!.status == 'cancelled')) {
        _pollTimer?.cancel();
        await loadRunResults(runId);
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
  }

  Future<void> _fetchRunStatus(String runId) async {
    try {
      final resp = await ApiClient.to.get('/automated/runs/$runId/status');
      if (resp.isOk) {
        runStatus.value = RunStatusModel.fromJson(Map<String, dynamic>.from(resp.body as Map));
      }
    } catch (_) {}
  }

  // ─── Historial y Resultados ─────────────────────────────────────────

  Future<void> loadRuns(String suiteId) async {
    isLoading.value = true;
    try {
      final resp = await ApiClient.to.get('/automated/suites/$suiteId/runs');
      if (resp.isOk) {
        final list = resp.body as List;
        runs.value = list
            .map((e) => AutomatedRunSummary.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadRunResults(String runId) async {
    try {
      final resp = await ApiClient.to.get('/automated/runs/$runId/results');
      if (resp.isOk) {
        final list = resp.body as List;
        results.value = list
            .map((e) => AutomatedRunResult.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
  }

  // ─── PDF ────────────────────────────────────────────────────────────

  Future<void> downloadPdf(String runId, {String logo = 'enerser'}) async {
    isLoading.value = true;
    try {
      final resp = await ApiClient.to.get('/automated/runs/$runId/pdf-data');
      if (resp.isOk) {
        final data = Map<String, dynamic>.from(resp.body as Map);
        final pdfBytes = await AutomatedPdfService.generate(data, logo);
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'pruebas_automatizadas_$runId.pdf',
        );
      }
    } catch (e) {
      errorMessage.value = 'Error generando PDF: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Análisis IA de errores ─────────────────────────────────────────

  final RxMap<String, String> errorAnalysis = <String, String>{}.obs;
  final RxMap<String, bool> analyzingError = <String, bool>{}.obs;

  Future<void> analyzeError(String resultId, String testName, String scriptCode,
      String errorMessage, String? consoleLog) async {
    analyzingError[resultId] = true;
    try {
      final resp = await ApiClient.to.post('/automated/analyze-error', {
        'test_name': testName,
        'script_code': scriptCode,
        'error_message': errorMessage,
        'console_log': consoleLog ?? '',
      });
      if (resp.isOk) {
        errorAnalysis[resultId] = resp.body['analysis'] as String;
      } else {
        errorAnalysis[resultId] = 'No se pudo analizar el error';
      }
    } catch (e) {
      errorAnalysis[resultId] = 'Error de conexión: $e';
    } finally {
      analyzingError[resultId] = false;
    }
  }

  /// Construye la URL para un screenshot automatizado por su file_id de Wasabi
  String screenshotUrl(String fileId) {
    return '${baseUrl}/automated/screenshots/$fileId';
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }
}
