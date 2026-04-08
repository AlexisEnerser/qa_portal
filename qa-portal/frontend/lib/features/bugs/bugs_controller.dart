import 'package:get/get.dart';

import '../../../core/api/api_client.dart';

class BugsController extends GetxController {
  static BugsController get to => Get.find();

  RxList<Map<String, dynamic>> bugs = <Map<String, dynamic>>[].obs;
  RxBool loading = false.obs;
  RxString error = ''.obs;

  String _currentExecutionId = '';

  Future<void> loadBugs(
    String executionId, {
    String? severity,
    String? status,
  }) async {
    loading.value = true;
    error.value = '';
    _currentExecutionId = executionId;
    try {
      final params = <String, dynamic>{};
      if (severity != null && severity != 'todos') {
        params['severity'] = severity;
      }
      if (status != null && status != 'todos') {
        params['status'] = status;
      }

      final query = params.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');

      final path = query.isEmpty
          ? '/qa/executions/$executionId/bugs'
          : '/qa/executions/$executionId/bugs?$query';

      final response = await ApiClient.to.get(path);
      if (response.isOk) {
        final List<dynamic> data = response.body as List<dynamic>;
        bugs.value = data
            .map((b) =>
                Map<String, dynamic>.from(b as Map<String, dynamic>))
            .toList();
      } else {
        error.value = 'Error al cargar bugs';
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<bool> updateBug(String bugId, Map<String, dynamic> body) async {
    try {
      final response = await ApiClient.to.put('/qa/bugs/$bugId', body);
      if (response.isOk) {
        await loadBugs(_currentExecutionId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteBug(String bugId, String executionId) async {
    try {
      final response = await ApiClient.to.delete('/qa/bugs/$bugId');
      if (response.isOk) {
        await loadBugs(executionId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> draftBug(String resultId) async {
    try {
      final response =
          await ApiClient.to.post('/qa/results/$resultId/bugs/draft', {});
      if (response.isOk) {
        return Map<String, dynamic>.from(
            response.body as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> createBug(
      String resultId, Map<String, dynamic> body) async {
    try {
      final response =
          await ApiClient.to.post('/qa/results/$resultId/bugs', body);
      return response.isOk;
    } catch (_) {
      return false;
    }
  }
}
