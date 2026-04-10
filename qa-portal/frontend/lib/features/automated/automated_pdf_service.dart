import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Genera PDF normativo de pruebas automatizadas a partir de datos del backend.
class AutomatedPdfService {
  static Future<Uint8List> generate(
    Map<String, dynamic> data,
    String logo,
  ) async {
    final pdf = pw.Document();

    final projectName = data['project_name'] ?? '';
    final suiteName = data['suite_name'] ?? '';
    final version = data['version'] ?? '';
    final environment = data['environment'] ?? '';
    final startedAt = data['started_at'] ?? '';
    final total = data['total'] ?? 0;
    final passed = data['passed'] ?? 0;
    final failed = data['failed'] ?? 0;
    final errorCount = data['error'] ?? 0;
    final successPct = data['success_pct'] ?? 0;
    final results = data['results'] as List<dynamic>? ?? [];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Reporte de Pruebas Automatizadas',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('$projectName — $suiteName',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
        ),
        build: (context) => [
          // Información general
          _section('Información General'),
          _infoRow('Proyecto', projectName),
          _infoRow('Suite', suiteName),
          _infoRow('Versión', version),
          _infoRow('Ambiente', environment),
          _infoRow('Fecha de ejecución', startedAt),
          pw.SizedBox(height: 16),

          // Resumen
          _section('Resumen de Resultados'),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
            headers: ['Total', 'Pasados', 'Fallidos', 'Errores', '% Éxito'],
            data: [
              ['$total', '$passed', '$failed', '$errorCount', '$successPct%'],
            ],
          ),
          pw.SizedBox(height: 20),

          // Detalle por test
          _section('Detalle de Resultados'),
          ...results.map((r) {
            final testName = r['test_name'] ?? '';
            final status = r['status'] ?? '';
            final duration = r['duration_ms'] ?? 0;
            final error = r['error_message'] ?? '';
            final color = status == 'passed'
                ? PdfColors.green
                : status == 'failed'
                    ? PdfColors.red
                    : PdfColors.orange;

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(testName,
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(4)),
                        child: pw.Text(status.toUpperCase(),
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Duración: ${duration}ms', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  if (error.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('Error: $error',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.red)),
                  ],
                ],
              ),
            );
          }),

          // Conclusión
          pw.SizedBox(height: 20),
          _section('Conclusión'),
          pw.Text(
            'Se ejecutaron $total pruebas automatizadas. '
            '$passed pasaron exitosamente ($successPct%). '
            '${failed > 0 ? "$failed pruebas fallaron. " : ""}'
            '${errorCount > 0 ? "$errorCount pruebas tuvieron errores de ejecución." : ""}',
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _section(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(title,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
      );

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 140,
              child: pw.Text('$label:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
          ],
        ),
      );
}
