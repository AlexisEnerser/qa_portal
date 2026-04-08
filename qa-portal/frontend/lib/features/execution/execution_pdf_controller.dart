import 'dart:ui';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import 'execution_controller.dart';
import 'execution_pdf_service.dart';

class ExecutionPdfController extends GetxController {
  static ExecutionPdfController get to => Get.find();

  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  Future<void> generateAndDownload(String executionId, Map<String, String> form) async {
    loading.value = true;
    error.value = '';

    try {
      final res = await ApiClient.to.get('/qa/executions/$executionId/pdf-data');

      if (!res.isOk) {
        final msg = res.body is Map ? (res.body['detail'] ?? 'Error al obtener datos') : 'Error al obtener datos';
        error.value = msg;
        Get.snackbar('Error', msg,
            backgroundColor: const Color(0xFFE53935), colorText: const Color(0xFFFFFFFF));
        return;
      }

      final pdfBytes = await ExecutionPdfService.generate(
        res.body as Map<String, dynamic>,
        form,
      );

      // Upload PDF to Wasabi for versioning
      final uploadError = await ExecutionController.to.uploadPdf(executionId, pdfBytes);
      if (uploadError != null) {
        // Non-blocking: still show the PDF even if upload fails
        Get.snackbar('Aviso', 'PDF generado pero no se pudo guardar la versión: $uploadError',
            backgroundColor: const Color(0xFFFF9800), colorText: const Color(0xFFFFFFFF));
      }

      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } catch (e) {
      error.value = 'Error al generar el PDF: $e';
      Get.snackbar('Error', error.value,
          backgroundColor: const Color(0xFFE53935), colorText: const Color(0xFFFFFFFF));
    } finally {
      loading.value = false;
    }
  }
}
