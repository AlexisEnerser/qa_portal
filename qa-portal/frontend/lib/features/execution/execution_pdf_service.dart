import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExecutionPdfService {
  static const double _w = 550;

  static final PdfColor _white = PdfColor.fromHex("#FFFFFF");
  static final PdfColor _black = PdfColor.fromHex("#000000");
  static final PdfColor _grey = PdfColor.fromHex("#999999");

  static final Map<String, PdfColor> _brandColors = {
    'ENERSER': PdfColor.fromHex("#17A2FF"),
    'XIGA': PdfColor.fromHex("#ED7D31"),
  };

  static final Map<String, PdfColor> _statusColors = {
    'passed': PdfColor.fromHex("#17B020"),
    'failed': PdfColor.fromHex("#E53935"),
    'blocked': PdfColor.fromHex("#FB8C00"),
    'not_applicable': PdfColor.fromHex("#757575"),
    'pending': PdfColor.fromHex("#9E9E9E"),
  };

  static final Map<String, String> _statusLabels = {
    'passed': 'Satisfactorio',
    'failed': 'Fallido',
    'blocked': 'Bloqueado',
    'not_applicable': 'No Aplica',
    'pending': 'Pendiente',
  };

  // ─── Helpers ────────────────────────────────────────────────────────────────

  static pw.Widget _box({
    required PdfColor bg,
    required String title,
    required pw.TextStyle style,
    required double width,
    pw.MainAxisAlignment align = pw.MainAxisAlignment.center,
    int row = 1,
    bool fit = false,
  }) {
    return pw.Container(
      height: 14.0 * row,
      width: width,
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: _black, width: 0.5),
      ),
      child: fit
          ? pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              child: pw.Text(title, style: style),
            )
          : pw.Row(mainAxisAlignment: align, children: [pw.Text(title, style: style)]),
    );
  }

  static int _rows(String text, int max) {
    if (text.isEmpty || max <= 0) return 1;
    final words = text.replaceAll('\n', ' ').split(' ');
    int rows = 1, len = 0;
    for (final w in words) {
      if (len + w.length + 1 > max) {
        rows++;
        len = w.length;
      } else {
        len += w.length + (len > 0 ? 1 : 0);
      }
    }
    return rows.clamp(1, 100);
  }

  static String _fmt(String? t) => (t ?? '').replaceAll('\n', ' ');

  // ─── Header / Footer ───────────────────────────────────────────────────────

  static pw.Widget _header(pw.MemoryImage logo, String brand) {
    return pw.SizedBox(
      height: 70,
      width: _w,
      child: pw.Stack(children: [
        pw.Positioned(left: 0, top: 10, child: pw.SizedBox(height: 50, width: 50, child: pw.Image(logo))),
        pw.Row(children: [
          pw.Spacer(),
          pw.Text('Batería de Prueba', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.Spacer(),
        ]),
        pw.Positioned(
          bottom: 10,
          right: 0,
          child: pw.Text('XMI-A28-F-23 $brand Batería de Prueba',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
      ]),
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    );
  }

  // ─── Sección: Información general ──────────────────────────────────────────

  static List<pw.Widget> _generalInfo(Map<String, dynamic> data, Map<String, String> form, PdfColor brand) {
    final exec = data['execution'] as Map<String, dynamic>;
    final project = data['project'] as Map<String, dynamic>;
    final summary = data['summary'] as Map<String, dynamic>;
    final analyst = data['analyst'] as String;
    final date = DateFormat('dd-MM-yyyy').format(DateTime.parse(exec['started_at']));

    // Format total duration
    final totalDuration = (data['total_duration_seconds'] as num?)?.toInt() ?? 0;
    final h = (totalDuration ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalDuration % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalDuration % 60).toString().padLeft(2, '0');
    final durationStr = '$h:$m:$s';

    return [
      _box(bg: brand, width: _w - 2, title: 'Información general de la Prueba',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _white)),
      _box(bg: _grey, width: _w - 2, title: 'Nombre de proyecto: ${project['name']}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _white)),
      _box(bg: _grey, width: _w - 2, title: 'Sesión: ${exec['name']}  |  Versión: ${exec['version']}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _white)),
      pw.Row(children: [
        _box(bg: _white, width: (_w / 4) - 1, title: 'Ambiente: ${exec['environment']}',
            style: pw.TextStyle(fontSize: 11, color: _black)),
        _box(bg: _white, width: (_w / 4) - 1, title: 'Fecha: $date',
            style: pw.TextStyle(fontSize: 11, color: _black)),
        _box(bg: _white, width: (_w / 4) - 1, title: 'Duración: $durationStr',
            style: pw.TextStyle(fontSize: 11, color: _black)),
        _box(bg: brand, width: (_w / 4), title: 'IP: ${form['ip'] ?? ''}',
            style: pw.TextStyle(fontSize: 11, color: _white)),
      ]),
      pw.Row(children: [
        _box(bg: _white, width: (_w / 2) - 1, title: 'Analista QA: $analyst',
            style: pw.TextStyle(fontSize: 11, color: _black)),
        _box(bg: _white, width: (_w / 2) - 1,
            title: 'Satisfactorios: ${summary['passed']}  |  Fallidos: ${summary['failed']}  |  Bloqueados: ${summary['blocked']}',
            style: pw.TextStyle(fontSize: 11, color: _black)),
      ]),
      pw.SizedBox(height: 10),
    ];
  }

  // ─── Sección: Control de versiones ─────────────────────────────────────────

  static List<pw.Widget> _versionControl(Map<String, dynamic> data, PdfColor brand) {
    final exec = data['execution'] as Map<String, dynamic>;
    final date = DateFormat('dd/MM/yyyy').format(DateTime.parse(exec['started_at']));

    return [
      _box(bg: brand, width: _w - 2, title: 'Control de versiones',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _white)),
      pw.Row(children: [
        _box(bg: _white, width: (_w / 2) - 1, title: 'Fecha: $date',
            style: pw.TextStyle(fontSize: 11, color: _black)),
        _box(bg: _white, width: (_w / 2) - 1, title: 'Número de versión: ${exec['version'] ?? '1'}',
            style: pw.TextStyle(fontSize: 11, color: _black)),
      ]),
      _box(bg: _white, width: _w - 2, title: 'Descripción: Reestructuración de formato y cambio a extensión PDF',
          style: pw.TextStyle(fontSize: 11, color: _black)),
      pw.SizedBox(height: 10),
    ];
  }

  // ─── Sección: Áreas participantes ──────────────────────────────────────────

  static List<pw.Widget> _areas(Map<String, String> form, PdfColor brand) {
    return [
      _box(bg: brand, width: _w - 2, title: 'Áreas participantes en la prueba',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _white)),
      _box(bg: _white, width: _w - 2, title: 'TI, QA, ${form['area'] ?? ''}',
          style: pw.TextStyle(fontSize: 11, color: _black)),
      pw.SizedBox(height: 10),
    ];
  }

  // ─── Test case individual (solo datos, sin capturas) ─────────────────────

  static pw.Widget _testCase(Map<String, dynamic> tc, int idx, int total) {
    final steps = tc['steps'] as List<dynamic>;

    String stepsText = '', expectedText = '';
    int stepsRows = 0, expectedRows = 0;

    if (steps.length == 1) {
      final testData = steps[0]['test_data'] != null && steps[0]['test_data'].toString().isNotEmpty
          ? ' [Datos: ${steps[0]['test_data']}]' : '';
      stepsText = _fmt(steps[0]['action']) + testData;
      expectedText = _fmt(steps[0]['expected_result']);
      stepsRows = _rows(stepsText, 80);
      expectedRows = _rows(expectedText, 80);
    } else {
      for (int i = 0; i < steps.length; i++) {
        final s = steps[i];
        final testData = s['test_data'] != null && s['test_data'].toString().isNotEmpty
            ? ' [Datos: ${s['test_data']}]' : '';
        stepsText += '${i + 1}) ${_fmt(s['action'])}$testData\n';
        expectedText += '${i + 1}) ${_fmt(s['expected_result'])}\n';
        stepsRows += _rows(s['action'] ?? '', 80);
        expectedRows += _rows(s['expected_result'] ?? '', 80);
      }
      stepsRows += 1;
      expectedRows += 1;
    }

    final statusColor = _statusColors[tc['status']] ?? _grey;
    final statusLabel = _statusLabels[tc['status']] ?? tc['status_label'] ?? '';
    final pct = total > 0 ? (100 / total).floorToDouble() : 0.0;

    pw.TextStyle lbl = pw.TextStyle(fontSize: 11, color: _black, fontWeight: pw.FontWeight.bold);
    pw.TextStyle val = pw.TextStyle(fontSize: 11, color: _black);
    pw.TextStyle valSm = pw.TextStyle(fontSize: 10, color: _black);
    double l = (_w / 3) - 1, r = (_w / 3 * 2) - 1;

    final precondRows = _rows(tc['preconditions'] ?? '', 73);
    final postcondRows = _rows(tc['postconditions'] ?? '', 73);
    bool hasNotes = tc['notes'] != null && tc['notes'].toString().isNotEmpty;
    final notesText = hasNotes
        ? ' ${tc['notes']}' : ' ${expectedText.trim()}';
    final notesRows = hasNotes ? _rows(tc['notes'] ?? expectedText, 73) : expectedRows;


    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Text('Caso de prueba ${idx + 1}: ${tc['title']}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Text('Módulo: ${tc['module_name']}  |  Asignado a: ${tc['assignee']}',
            style: pw.TextStyle(fontSize: 10, color: _grey)),
        pw.SizedBox(height: 4),
        // Precondición
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          precondRows == 1
              ? _box(bg: _white, width: l, title: ' Precondición:', align: pw.MainAxisAlignment.start, style: lbl)
              : _box(bg: _white, width: l, title: ' Precondición:', align: pw.MainAxisAlignment.start,
                  row: precondRows, fit: true, style: lbl),
          precondRows == 1
              ? _box(bg: _white, width: r, title: ' ${tc['preconditions'] ?? ''}',
                  align: pw.MainAxisAlignment.start, style: val)
              : _box(bg: _white, width: r, title: ' ${tc['preconditions'] ?? ''}',
                  row: precondRows, fit: true, style: val),
        ]),
        // Menú / Caso de prueba
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _box(bg: _white, width: l, title: ' Menú / Caso de prueba:', align: pw.MainAxisAlignment.start, style: lbl),
          postcondRows == 1
              ? _box(bg: _white, width: r, title: ' ${tc['postconditions'] ?? ''}',
                  align: pw.MainAxisAlignment.start, style: val)
              : _box(bg: _white, width: r, title: ' ${tc['postconditions'] ?? ''}',
                  row: postcondRows, fit: true, style: val),
        ]),
        // Pasos
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _box(bg: _white, width: l, title: ' Descripción de pasos:', align: pw.MainAxisAlignment.start,
              style: pw.TextStyle(fontSize: 10, color: _black, fontWeight: pw.FontWeight.bold)),
          _box(bg: _white, width: r, title: stepsText, row: stepsRows, fit: true, style: valSm),
        ]),
        // Resultado esperado
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _box(bg: _white, width: l, title: ' Resultado esperado:', align: pw.MainAxisAlignment.start, style: lbl),
          _box(bg: _white, width: r, title: expectedText, row: expectedRows, fit: true, style: valSm),
        ]),
        // Estatus
        pw.Row(children: [
          _box(bg: _white, width: l, title: ' Estatus:', align: pw.MainAxisAlignment.start, style: lbl),
          _box(bg: _white, width: r, title: ' $statusLabel', align: pw.MainAxisAlignment.start,
              style: pw.TextStyle(fontSize: 10, color: statusColor, fontWeight: pw.FontWeight.bold)),
        ]),
        // Porcentaje
        pw.Row(children: [
          _box(bg: _white, width: l, title: ' Porcentaje:', align: pw.MainAxisAlignment.start, style: lbl),
          _box(bg: _white, width: r, title: ' $pct%', align: pw.MainAxisAlignment.start, style: val),
        ]),
        // Resultado obtenido
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _box(bg: _white, width: l, title: ' Resultado obtenido:', align: pw.MainAxisAlignment.start, style: lbl),
          _box(bg: _white, width: r, title: notesText, row: notesRows, fit: true, style: valSm),
        ]),
      ],
    );
  }

  // ─── Capturas de un test case (como ListView para que pueda dividirse entre páginas) ──

  static pw.Widget _screenshotsList(List<dynamic> screenshots) {
    return pw.ListView.builder(
      itemCount: screenshots.length,
      itemBuilder: (_, index) {
        try {
          final bytes = base64Decode(screenshots[index]['base64'] as String);
          return pw.Image(
            pw.MemoryImage(bytes),
            width: _w,
            height: (_w * 1080) / 1920,
            fit: pw.BoxFit.fitHeight,
          );
        } catch (_) {
          return pw.SizedBox.shrink();
        }
      },
    );
  }

  // ─── Sección: Conclusión ───────────────────────────────────────────────────

  static List<pw.Widget> _conclusion(Map<String, dynamic> data, PdfColor brand) {
    final summary = data['summary'] as Map<String, dynamic>;
    final exec = data['execution'] as Map<String, dynamic>;
    final pct = summary['progress_pct'] ?? 0.0;

    pw.TextStyle lbl = pw.TextStyle(fontSize: 11, color: _black, fontWeight: pw.FontWeight.bold);
    pw.TextStyle val = pw.TextStyle(fontSize: 11, color: _black);
    pw.TextStyle valSm = pw.TextStyle(fontSize: 9, color: _black);

    return [
      _box(bg: brand, width: _w - 2, title: 'Conclusión de las pruebas',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _white)),
      pw.Row(children: [
        _box(bg: _white, width: (_w / 4) - 1, title: ' Completado:', align: pw.MainAxisAlignment.start, style: lbl),
        _box(bg: _white, width: _w / 8, title: '$pct%', style: val),
        _box(bg: _white, width: (_w / 4) - 1, title: ' Comentarios:', align: pw.MainAxisAlignment.start, style: lbl),
        _box(bg: _white, width: (_w / 8) * 3, title: 'Pruebas realizadas en ambiente ${exec['environment']}', style: valSm),
      ]),
      pw.Row(children: [
        _box(bg: _white, width: (_w / 4) - 1, title: ' Resultado:', align: pw.MainAxisAlignment.start, style: lbl),
        _box(bg: _white, width: _w / 8,
            title: '${summary['passed']}/${summary['total']}', style: val),
        _box(bg: _white, width: (_w / 4) - 1, title: ' Ambientes controlados:', align: pw.MainAxisAlignment.start, style: lbl),
        _box(bg: _white, width: (_w / 8) * 3, title: 'Pruebas en ${exec['environment']}', style: val),
      ]),
      pw.SizedBox(height: 10),
    ];
  }

  // ─── Sección: Mejoras aplicadas ────────────────────────────────────────────

  static List<pw.Widget> _enhancements(Map<String, String> form, List<String> modules, PdfColor brand) {
    final enhText = form['enhancements'] ?? '';
    final modText = modules.join(', ');
    final enhRows = _rows(enhText, 40).clamp(1, 20);

    return [
      _box(bg: brand, width: _w - 2, title: 'Mejoras Aplicadas',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _white)),
      pw.Row(children: [
        _box(bg: _grey, width: (_w / 3) - 1, title: 'Módulo / Proceso',
            style: pw.TextStyle(fontSize: 11, color: _white)),
        _box(bg: _grey, width: ((_w / 3) * 2) - 1, title: 'Descripción',
            style: pw.TextStyle(fontSize: 11, color: _white)),
      ]),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _box(bg: _white, width: (_w / 3) - 1, title: modText, fit: true, row: enhRows,
            style: pw.TextStyle(fontSize: 11, color: _black)),
        _box(bg: _white, width: ((_w / 3) * 2) - 1, title: enhText, fit: true, row: enhRows,
            style: pw.TextStyle(fontSize: 11, color: _black)),
      ]),
      pw.SizedBox(height: 10),
    ];
  }

  // ─── Sección: Firmas ──────────────────────────────────────────────────────

  static List<pw.Widget> _signatures(Map<String, String> form, PdfColor brand) {
    pw.TextStyle s = pw.TextStyle(fontSize: 11, color: _black);
    double bw = _w * 0.45;

    pw.Widget signBlock(String name, String position, String role) {
      return pw.Column(children: [
        _box(bg: _white, width: bw, title: '', style: s, row: 4),
        _box(bg: _white, width: bw, title: name, style: s),
        _box(bg: _white, width: bw, title: position, style: s),
        if (role.isNotEmpty) _box(bg: _white, width: bw, title: role, style: s)
      ]);
    }

    return [
      _box(bg: brand, width: _w - 2, title: 'Firmas',
          style: pw.TextStyle(fontSize: 11, color: _white, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 20),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
        signBlock(form['requestor'] ?? '', form['requestorPosition'] ?? '', 'Solicitante'),
      ]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        signBlock(form['techlead'] ?? '', form['techleadPosition'] ?? '', 'Tech Lead'),
      ]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
        signBlock(form['developer'] ?? '', 'Desarrollador', ''),
      ]),
    ];
  }

  // ─── Generar PDF ───────────────────────────────────────────────────────────

  static Future<Uint8List> generate(Map<String, dynamic> data, Map<String, String> form) async {
    final pdf = pw.Document();
    final brand = form['logo'] ?? 'ENERSER';
    final brandColor = _brandColors[brand] ?? _brandColors['ENERSER']!;

    final ByteData imgData = await rootBundle.load('assets/images/${brand.toLowerCase()}.png');
    final logo = pw.MemoryImage(imgData.buffer.asUint8List());

    final testCases = data['test_cases'] as List<dynamic>;
    final total = testCases.length;

    // Extraer nombres de módulos únicos
    final modules = testCases
        .map((tc) => (tc as Map<String, dynamic>)['module_name'] as String? ?? '')
        .toSet()
        .where((m) => m.isNotEmpty)
        .toList();

    // Primera página: info general + primer test case + sus capturas
    final firstTc = testCases[0] as Map<String, dynamic>;
    final firstScreenshots = firstTc['screenshots'] as List<dynamic>? ?? [];

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(32),
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      maxPages: 999,
      header: (ctx) => _header(logo, brand),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        ..._generalInfo(data, form, brandColor),
        ..._versionControl(data, brandColor),
        ..._areas(form, brandColor),
        _testCase(firstTc, 0, total),
        pw.SizedBox(height: 10),
        if (firstScreenshots.isNotEmpty)
          _screenshotsList(firstScreenshots),
      ],
    ));

    // Un MultiPage por cada test case restante (datos + capturas)
    for (int i = 1; i < testCases.length; i++) {
      final tc = testCases[i] as Map<String, dynamic>;
      final screenshots = tc['screenshots'] as List<dynamic>? ?? [];

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        maxPages: 999,
        header: (ctx) => _header(logo, brand),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          _testCase(tc, i, total),
          pw.SizedBox(height: 10),
          if (screenshots.isNotEmpty)
            _screenshotsList(screenshots),
        ],
      ));
    }

    // Última página: conclusión, mejoras y firmas
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(32),
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      maxPages: 999,
      header: (ctx) => _header(logo, brand),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        ..._conclusion(data, brandColor),
        ..._enhancements(form, modules, brandColor),
        ..._signatures(form, brandColor),
      ],
    ));

    return pdf.save();
  }
}
