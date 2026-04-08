import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class QenginePdfService {
  static const double _pageWidth = 540;

  static final PdfColor _primaryColor = PdfColor.fromHex("#17A2FF");
  static final PdfColor _white = PdfColor.fromHex("#FFFFFF");
  static final PdfColor _black = PdfColor.fromHex("#000000");
  static final PdfColor _grey = PdfColor.fromHex("#999999");
  static final PdfColor _lightGrey = PdfColor.fromHex("#F5F5F5");

  static pw.Widget _box({
    required PdfColor backgroundColor,
    required String title,
    required pw.TextStyle textStyle,
    required double width,
    pw.MainAxisAlignment mainAxisAlignment = pw.MainAxisAlignment.center,
    int row = 1,
    bool fitContent = false,
  }) {
    const double height = 15;
    return pw.Container(
      height: fitContent ? null : height * row,
      width: width,
      decoration: pw.BoxDecoration(
        color: backgroundColor,
        border: pw.Border.all(color: _black, width: 0.5),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: pw.Row(
          mainAxisAlignment: mainAxisAlignment,
          children: [pw.Expanded(child: pw.Text(title, style: textStyle, textAlign: (mainAxisAlignment == pw.MainAxisAlignment.center) ? pw.TextAlign.center : pw.TextAlign.left))],
        ),
      ),
    );
  }

  static pw.Widget _header(double width, pw.MemoryImage logo, String logoName) {
    return pw.SizedBox(
      height: 70,
      width: width,
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 0,
            top: 10,
            child: pw.SizedBox(height: 50, width: 50, child: pw.Image(logo)),
          ),
          pw.Center(
            child: pw.Text(
              'Batería de Prueba Automatizada',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Positioned(
            bottom: 10,
            right: 0,
            child: pw.Text(
              'XMI-A28-F-23 $logoName',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 9, color: _grey, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.TableRow _metaRow(String role, String nameTitle) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(role, style: pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(nameTitle, style: pw.TextStyle(fontSize: 9))),
      ],
    );
  }

  static Future<Uint8List> generate(Map<String, dynamic> data, String logoName) async {
    final pdf = pw.Document();

    final ByteData imageData = await rootBundle.load('assets/images/${logoName.toLowerCase()}.png');
    final logo = pw.MemoryImage(imageData.buffer.asUint8List());

    final results = data['results'] ?? {};
    final List<dynamic> testCaseResults = results['testcaseresults'] ?? [];
    final List<dynamic> images = data['images'] ?? [];
    final Map<String, dynamic> meta = data['meta'] ?? {};

    // Campos normativos
    final String environment = meta['environment'] ?? 'QA';
    final String ipAddress = meta['ip_address'] ?? '';
    final String analystType = meta['analyst_type'] ?? '';
    final String area = meta['area'] ?? '';
    final String module = meta['module'] ?? '';
    final String requestor = meta['requestor'] ?? '';
    final String requestorPosition = meta['requestor_position'] ?? '';
    final String developer = meta['developer'] ?? '';
    final String techlead = meta['techlead'] ?? '';
    final String techleadPosition = meta['techlead_position'] ?? '';
    final String coordinator = meta['coordinator'] ?? '';
    final String huEntregable = meta['hu_entregable'] ?? '';
    final String zohoprojects = meta['zohoprojects'] ?? (results['project_name'] ?? 'N/A');
    final String dateStr = results['executed_on'] ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _header(_pageWidth, logo, logoName.toUpperCase()),
        footer: (context) => _footer(context),
        build: (context) => [
          // 1. Información General
          _box(backgroundColor: _primaryColor, width: _pageWidth, title: 'Información general de la Prueba (Zoho QEngine)', textStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _white)),
          _box(backgroundColor: _grey, width: _pageWidth, title: 'Nombre de proyecto: $zohoprojects', textStyle: pw.TextStyle(fontSize: 11, color: _white, fontWeight: pw.FontWeight.bold)),
          _box(backgroundColor: _grey, width: _pageWidth, title: logoName.toUpperCase(), textStyle: pw.TextStyle(fontSize: 11, color: _white, fontWeight: pw.FontWeight.bold)),
          pw.Row(children: [
            _box(backgroundColor: _white, width: _pageWidth / 3, title: 'Ambiente: $environment', textStyle: pw.TextStyle(fontSize: 10, color: _black), mainAxisAlignment: pw.MainAxisAlignment.start),
            _box(backgroundColor: _white, width: _pageWidth / 3, title: dateStr.isNotEmpty ? 'Fecha: $dateStr' : 'Fecha: N/A', textStyle: pw.TextStyle(fontSize: 10, color: _black)),
            _box(backgroundColor: _primaryColor, width: _pageWidth / 3, title: ipAddress.isNotEmpty ? 'IP: $ipAddress' : 'IP: N/A', textStyle: pw.TextStyle(fontSize: 10, color: _white)),
          ]),
          pw.Row(children: [
            _box(backgroundColor: _white, width: _pageWidth / 2, title: 'Analista QA: $analystType', textStyle: pw.TextStyle(fontSize: 10, color: _black), mainAxisAlignment: pw.MainAxisAlignment.start),
            _box(backgroundColor: _white, width: _pageWidth / 2, title: 'Tiempo estimado de ejecución: N/A', textStyle: pw.TextStyle(fontSize: 10, color: _black)),
          ]),

          pw.SizedBox(height: 10),

          // 2. Control de Versiones
          _box(backgroundColor: _primaryColor, width: _pageWidth, title: 'Control de versiones', textStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _white)),
          _box(backgroundColor: _white, width: _pageWidth, title: 'Descripción: Emisión de reporte automatizado vía QA Portal', textStyle: pw.TextStyle(fontSize: 10, color: _black), mainAxisAlignment: pw.MainAxisAlignment.start),

          pw.SizedBox(height: 10),

          // 3. Áreas participantes
          _box(backgroundColor: _primaryColor, width: _pageWidth, title: 'Áreas participantes en la prueba', textStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _white)),
          _box(backgroundColor: _white, width: _pageWidth, title: 'TI, QA${area.isNotEmpty ? ", $area" : ""}', textStyle: pw.TextStyle(fontSize: 10, color: _black), mainAxisAlignment: pw.MainAxisAlignment.start),

          if (requestor.isNotEmpty || developer.isNotEmpty || techlead.isNotEmpty || coordinator.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: _black, width: 0.5),
              columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(1)},
              children: [
                pw.TableRow(decoration: pw.BoxDecoration(color: _lightGrey), children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rol', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Nombre / Puesto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                ]),
                if (requestor.isNotEmpty) _metaRow('Solicitante', requestorPosition.isNotEmpty ? '$requestor — $requestorPosition' : requestor),
                if (developer.isNotEmpty) _metaRow('Desarrollador', developer),
                if (techlead.isNotEmpty) _metaRow('Tech Lead', techleadPosition.isNotEmpty ? '$techlead — $techleadPosition' : techlead),
                if (coordinator.isNotEmpty) _metaRow('Coordinador', coordinator),
              ],
            ),
          ],

          if (module.isNotEmpty || huEntregable.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            if (module.isNotEmpty) _box(backgroundColor: _white, width: _pageWidth, title: 'Módulo: $module', textStyle: pw.TextStyle(fontSize: 10, color: _black), mainAxisAlignment: pw.MainAxisAlignment.start),
            if (huEntregable.isNotEmpty) _box(backgroundColor: _white, width: _pageWidth, title: 'HU Entregable: $huEntregable', textStyle: pw.TextStyle(fontSize: 10, color: _black), mainAxisAlignment: pw.MainAxisAlignment.start),
          ],

          pw.SizedBox(height: 20),

          // 4. Resultados de casos de prueba
          ...testCaseResults.map((tc) {
            final String statusLabel = tc['status_label'] ?? tc['result'] ?? 'N/A';
            final bool isPassed = statusLabel.toLowerCase() == 'pass' || statusLabel.toLowerCase() == 'passed';
            final PdfColor statusColor = isPassed ? PdfColor.fromHex("#17B020") : PdfColor.fromHex("#E53935");

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text("Caso de prueba: ${tc['testcase_name'] ?? tc['testcase_id'] ?? 'N/A'}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 5),
                _box(backgroundColor: _white, width: _pageWidth, title: 'Descripción de pasos: Ver detalles en plataforma QEngine', textStyle: pw.TextStyle(fontSize: 10), mainAxisAlignment: pw.MainAxisAlignment.start),
                pw.Row(children: [
                  _box(backgroundColor: _white, width: _pageWidth * 0.4, title: 'Estatus:', textStyle: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold), mainAxisAlignment: pw.MainAxisAlignment.start),
                  _box(backgroundColor: _white, width: _pageWidth * 0.6, title: statusLabel, textStyle: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: statusColor), mainAxisAlignment: pw.MainAxisAlignment.start),
                ]),
                pw.Row(children: [
                  _box(backgroundColor: _white, width: _pageWidth * 0.4, title: 'Porcentaje:', textStyle: pw.TextStyle(fontSize: 10), mainAxisAlignment: pw.MainAxisAlignment.start),
                  _box(backgroundColor: _white, width: _pageWidth * 0.6, title: isPassed ? '100%' : '0%', textStyle: pw.TextStyle(fontSize: 10), mainAxisAlignment: pw.MainAxisAlignment.start),
                ]),
                pw.SizedBox(height: 10),
              ],
            );
          }),

          // 5. Galería de Capturas
          if (images.isNotEmpty) ...[
            pw.NewPage(),
            pw.Text('Evidencias (Capturas de Pantalla)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            ...images.map((img) {
              try {
                final bytes = base64Decode(img['imageBase64'] as String);
                final memoryImg = pw.MemoryImage(bytes);
                return pw.Column(children: [
                  pw.Image(memoryImg, width: _pageWidth, fit: pw.BoxFit.fitWidth),
                  pw.SizedBox(height: 10),
                  pw.Divider(),
                ]);
              } catch (_) {
                return pw.SizedBox();
              }
            }),
          ],
        ],
      ),
    );

    return pdf.save();
  }
}
