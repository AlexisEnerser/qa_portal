import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SonarPdfService {
  static const double _w = 540;

  static final PdfColor _primary = PdfColor.fromHex("#17A2FF");
  static final PdfColor _white = PdfColor.fromHex("#FFFFFF");
  static final PdfColor _black = PdfColor.fromHex("#000000");
  static final PdfColor _grey = PdfColor.fromHex("#999999");
  static final PdfColor _lightGrey = PdfColor.fromHex("#F5F5F5");
  static final PdfColor _red = PdfColor.fromHex("#E53935");
  static final PdfColor _orange = PdfColor.fromHex("#FB8C00");

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Removes characters that the default PDF font cannot render (emojis,
  /// special Unicode symbols, etc.) to avoid □ / ▯ boxes in the output.
  static String _sanitize(String text) {
    // First, replace common Unicode alternatives with ASCII equivalents
    var clean = text
        .replaceAll('\u201C', '"')   // left double quote "
        .replaceAll('\u201D', '"')   // right double quote "
        .replaceAll('\u2018', "'")   // left single quote '
        .replaceAll('\u2019', "'")   // right single quote '
        .replaceAll('\u2013', '-')   // en dash –
        .replaceAll('\u2014', '-')   // em dash —
        .replaceAll('\u2026', '...') // ellipsis …
        .replaceAll('\u2022', '-')   // bullet •
        .replaceAll('\u2192', '->')  // arrow →
        .replaceAll('\u2190', '<-')  // arrow ←
        .replaceAll('\u2713', 'OK')  // check mark ✓
        .replaceAll('\u2714', 'OK')  // heavy check ✔
        .replaceAll('\u2715', 'X')   // multiplication X ✕
        .replaceAll('\u2716', 'X')   // heavy X ✖
        .replaceAll('\u2717', 'X')   // ballot X ✗
        .replaceAll('\u2718', 'X')   // heavy ballot X ✘
        .replaceAll('\u00D7', 'x')   // multiplication sign ×
        .replaceAll('\u00B7', '-')   // middle dot ·
        .replaceAll('\u200B', '')    // zero-width space
        .replaceAll('\u00A0', ' '); // non-breaking space

    // Keep only printable ASCII (0x20-0x7E) plus accented Latin chars (0xC0-0xFF)
    // This covers: a-z A-Z 0-9 punctuation spaces and áéíóúñüÁÉÍÓÚÑÜ
    clean = clean.replaceAll(RegExp(r'[^\x0A\x0D\x20-\x7E\xC0-\xFF]'), '');

    return clean;
  }

  static pw.Widget _cell(String text, double width, {PdfColor? bg, pw.TextStyle? style, int maxRow = 1}) {
    final s = style ?? pw.TextStyle(fontSize: 10, color: _black);
    return pw.Container(
      width: width,
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      decoration: pw.BoxDecoration(
        color: bg ?? _white,
        border: pw.Border.all(color: _black, width: 0.5),
      ),
      child: pw.Text(_sanitize(text), style: s),
    );
  }

  static pw.Widget _headerCell(String text, double width) {
    return _cell(text, width,
        bg: _grey,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _white));
  }

  static pw.Widget _titleBar(String text, {PdfColor? bg}) {
    return pw.Container(
      width: _w,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: pw.BoxDecoration(
        color: bg ?? _primary,
        border: pw.Border.all(color: _black, width: 0.5),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _white),
          textAlign: pw.TextAlign.center),
    );
  }

  // ─── Header / Footer ─────────────────────────────────────────────────────

  static pw.Widget _header(pw.MemoryImage logo) {
    return pw.SizedBox(
      height: 70, width: _w,
      child: pw.Stack(children: [
        pw.Positioned(left: 0, top: 10, child: pw.SizedBox(height: 50, width: 50, child: pw.Image(logo))),
        pw.Center(child: pw.Text('Reporte de Análisis de Código - SonarQube',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
        pw.Positioned(bottom: 10, right: 0,
            child: pw.Text('XMI-A28-F-SONAR', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
      ]),
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 9, color: _grey)),
    );
  }

  // ─── Markdown-to-PDF parser ───────────────────────────────────────────────

  /// Parses the AI markdown response into proper PDF widgets (headings, tables, paragraphs).
  static List<pw.Widget> _parseAnalysis(String analysis) {
    final lines = analysis.split('\n');
    final widgets = <pw.Widget>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();

      // Skip empty lines and horizontal rules
      if (line.isEmpty || RegExp(r'^-{3,}$').hasMatch(line)) {
        i++;
        continue;
      }

      // Heading ## or ###
      if (line.startsWith('#')) {
        final text = _sanitize(line.replaceAll(RegExp(r'^#+\s*'), ''));
        widgets.add(pw.SizedBox(height: 8));
        widgets.add(pw.Container(
          width: _w,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          decoration: pw.BoxDecoration(
            color: _primary,
            border: pw.Border.all(color: _black, width: 0.5),
          ),
          child: pw.Text(text,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _white)),
        ));
        i++;
        continue;
      }

      // Markdown table: starts with | and has at least one more |
      if (line.startsWith('|') && line.contains('|', 1)) {
        // Collect all table lines
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          final tl = lines[i].trim();
          // Skip separator rows like |---|---|
          if (!RegExp(r'^\|[\s\-:|\+]+\|$').hasMatch(tl)) {
            tableLines.add(tl);
          }
          i++;
        }

        if (tableLines.isEmpty) continue;

        // Parse header
        final headerCells = _parseTableRow(tableLines[0]);
        final colCount = headerCells.length;
        if (colCount == 0) continue;

        final colWidth = _w / colCount;

        // Header row
        widgets.add(pw.Row(
          children: headerCells.map((c) => _headerCell(c, colWidth)).toList(),
        ));

        // Data rows
        for (int r = 1; r < tableLines.length; r++) {
          final cells = _parseTableRow(tableLines[r]);
          // Pad or trim to match column count
          final padded = List<String>.generate(colCount, (idx) => idx < cells.length ? cells[idx] : '');
          widgets.add(pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: padded.map((c) => _cell(c, colWidth, style: pw.TextStyle(fontSize: 8, color: _black))).toList(),
          ));
        }

        widgets.add(pw.SizedBox(height: 6));
        continue;
      }

      // Bold line (starts with **)
      if (line.startsWith('**') && line.endsWith('**')) {
        final text = _sanitize(line.replaceAll('**', ''));
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
          child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ));
        i++;
        continue;
      }

      // Regular paragraph
      final clean = _sanitize(line
          .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1')
          .replaceAll('<br>', '\n')
          .replaceAll('`', ''));
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2, left: 2, right: 2),
        child: pw.Text(clean, style: pw.TextStyle(fontSize: 9, lineSpacing: 1.3)),
      ));
      i++;
    }

    return widgets;
  }

  /// Parses a markdown table row like "| a | b | c |" into ["a", "b", "c"]
  static List<String> _parseTableRow(String row) {
    return row
        .split('|')
        .map((c) => _sanitize(c.trim()))
        .where((c) => c.isNotEmpty)
        .toList();
  }

  // ─── Generate PDF ─────────────────────────────────────────────────────────

  static Future<Uint8List> generate(Map<String, dynamic> data, String logoName) async {
    final pdf = pw.Document();

    final ByteData imageData = await rootBundle.load('assets/images/${logoName.toLowerCase()}.png');
    final logo = pw.MemoryImage(imageData.buffer.asUint8List());

    final String project = data['project'] ?? 'Unknown';
    final int issuesCount = data['issues_count'] ?? 0;
    final int vulnCount = data['vulnerabilities_count'] ?? 0;
    final String analysis = data['analysis'] ?? 'No hay análisis disponible.';
    final List<dynamic> rawIssues = data['raw_issues'] ?? [];
    final String dateStr = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());

    // Column widths for issues table
    const double colComp = _w * 0.30;
    const double colLine = 50;
    const double colSev = 60;
    final double colMsg = _w - colComp - colLine - colSev;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 999,
        header: (_) => _header(logo),
        footer: (ctx) => _footer(ctx),
        build: (_) => [
          // ── Info general ──────────────────────────────────────────
          _titleBar('Información del Análisis SonarQube'),
          pw.Row(children: [
            _cell('Proyecto: $project', _w * 0.6),
            _cell('Fecha: $dateStr', _w * 0.4),
          ]),
          pw.Row(children: [
            _cell('Issues Críticos: $issuesCount', _w / 2,
                bg: _red, style: pw.TextStyle(fontSize: 11, color: _white, fontWeight: pw.FontWeight.bold)),
            _cell('Vulnerabilidades: $vulnCount', _w / 2,
                bg: _orange, style: pw.TextStyle(fontSize: 11, color: _white, fontWeight: pw.FontWeight.bold)),
          ]),

          pw.SizedBox(height: 12),

          // ── Análisis IA (parsed from markdown) ────────────────────
          _titleBar('Análisis IA (GPT)', bg: _grey),
          ..._parseAnalysis(analysis),

          pw.SizedBox(height: 12),

          // ── Detalle de hallazgos ──────────────────────────────────
          if (rawIssues.isNotEmpty) ...[
            _titleBar('Detalle de Hallazgos (Top ${rawIssues.take(20).length})'),

            // Table header
            pw.Row(children: [
              _headerCell('Componente', colComp),
              _headerCell('Línea', colLine),
              _headerCell('Severidad', colSev),
              _headerCell('Mensaje', colMsg),
            ]),

            // Table rows — each as separate widget for pagination
            ...rawIssues.take(20).map((issue) {
              final component = (issue['component']?.toString() ?? '').split(':').last;
              final line = issue['line']?.toString() ?? 'N/A';
              final severity = issue['severity']?.toString() ?? '';
              final message = issue['message']?.toString() ?? '';

              PdfColor sevBg = _white;
              if (severity == 'CRITICAL' || severity == 'BLOCKER') sevBg = PdfColor.fromHex("#FFCDD2");
              if (severity == 'MAJOR') sevBg = PdfColor.fromHex("#FFE0B2");

              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _cell(component, colComp, style: pw.TextStyle(fontSize: 8, color: _black)),
                  _cell(line, colLine, style: pw.TextStyle(fontSize: 8, color: _black)),
                  _cell(severity, colSev, bg: sevBg, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _black)),
                  _cell(message, colMsg, style: pw.TextStyle(fontSize: 8, color: _black)),
                ],
              );
            }),
          ],
        ],
      ),
    );

    return pdf.save();
  }
}
