import 'package:get/get.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

import '../../core/api/api_client.dart';
import 'sonar_pdf_service.dart';
import 'posting_pdf_service.dart';
import 'qengine_pdf_service.dart';

class ReportsController extends GetxController {
  static ReportsController get to => Get.find();

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  
  // Estado para el logo seleccionado por el usuario
  final RxString selectedLogo = 'enerser'.obs;
  final List<String> logoOptions = ['enerser', 'xiga', 'eft'];

  // 1. Generar PDF de SonarQube
  Future<void> downloadSonarPdf(String projectKey) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await ApiClient.to.get('/sonar/analysis/$projectKey');
      if (response.isOk) {
        final Uint8List pdfBytes = await SonarPdfService.generate(
          response.body as Map<String, dynamic>,
          selectedLogo.value,
        );
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'reporte_sonar_$projectKey.pdf',
        );
      } else {
        errorMessage.value = response.body['detail'] ?? 'Error al obtener datos de Sonar';
      }
    } catch (e) {
      errorMessage.value = 'Error generando PDF de Sonar: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // 2. Generar PDF de Hoja de Posteo
  // postingData debe incluir: org, repo, branch, commit_sha,
  // y los campos normativos: business, product, project_detail,
  // user_rollback, user_rollback_mail
  Future<void> downloadPostingSheetPdf(Map<String, dynamic> postingData) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await ApiClient.to.post('/github/posting-sheet-data', postingData);
      
      if (response.isOk) {
        final Uint8List pdfBytes = await PostingPdfService.generate(
          response.body as Map<String, dynamic>,
          selectedLogo.value,
        );
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'hoja_de_posteo_${postingData['repo']}.pdf',
        );
      } else {
        errorMessage.value = response.body['detail'] ?? 'Error al generar Hoja de Posteo';
      }
    } catch (e) {
      errorMessage.value = 'Error generando Hoja de Posteo: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // 3. Generar PDF de QEngine
  Future<void> downloadQenginePdf(String projectId, String testRunId) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await ApiClient.to.post('/qengine/report-data', {
        'project_id': projectId,
        'test_run_id': testRunId,
        'extract_images': true,
      });

      if (response.isOk) {
        final Uint8List pdfBytes = await QenginePdfService.generate(
          response.body as Map<String, dynamic>,
          selectedLogo.value,
        );
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'bateria_qengine_$projectId.pdf',
        );
      } else {
        errorMessage.value = response.body['detail'] ?? 'Error al obtener datos de QEngine';
      }
    } catch (e) {
      errorMessage.value = 'Error generando PDF de QEngine: $e';
    } finally {
      isLoading.value = false;
    }
  }
}
