import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PostingPdfService {
  static const double _pageWidth = 540;

  static final PdfColor _primaryColor = PdfColor.fromHex("#17A2FF");
  static final PdfColor _white = PdfColor.fromHex("#FFFFFF");
  static final PdfColor _black = PdfColor.fromHex("#000000");
  static final PdfColor _grey = PdfColor.fromHex("#999999");
  static final PdfColor _lightGrey = PdfColor.fromHex("#F5F5F5");

  static String _formatString(String? text, int size) {
    if (text == null) return "";
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % size == 0 && i != text.length - 1) {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }

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
        padding: const pw.EdgeInsets.all(3),
        child: pw.Row(
          mainAxisAlignment: mainAxisAlignment,
          children: [pw.Expanded(child: pw.Text(title, style: textStyle, textAlign: (mainAxisAlignment == pw.MainAxisAlignment.center) ? pw.TextAlign.center : pw.TextAlign.left))],
        ),
      ),
    );
  }

  static pw.Widget _header(double width, pw.MemoryImage logo) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.start,
          children: [
            pw.SizedBox(height: 50, width: 50, child: pw.Image(logo)),
            pw.Spacer(),
            pw.Text(
              'Solicitud de Instalación de Componentes Modificados',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.Divider(color: _primaryColor, thickness: 1),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: _primaryColor, thickness: 0.5),
        pw.Row(
          children: [
            pw.Text('XMI-A28-F-29 Hoja de Posteo', style: pw.TextStyle(fontSize: 10)),
            pw.Spacer(),
            pw.Text(
              "Página ${context.pageNumber} de ${context.pagesCount}",
              style: pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }

  static Future<Uint8List> generate(Map<String, dynamic> data, String logoName) async {
    final pdf = pw.Document();

    final ByteData imageData = await rootBundle.load('assets/images/${logoName.toLowerCase()}.png');
    final logo = pw.MemoryImage(imageData.buffer.asUint8List());

    final String developer = data['developer_name'] ?? 'Desconocido';
    final String email = data['developer_email'] ?? 'Sin correo';
    final String date = data['date'] ?? 'N/A';
    final String sha = data['sha'] ?? 'N/A';
    final String rollbackSha = data['rollback_sha'] ?? 'N/A';
    final String message = data['message'] ?? '(sin mensaje)';
    final List<dynamic> files = data['files'] ?? [];
    // Campos normativos
    final String business = data['business'] ?? '';
    final String product = data['product'] ?? '';
    final String projectDetail = data['project_detail'] ?? '';
    final String userRollback = data['user_rollback'] ?? '';
    final String userRollbackMail = data['user_rollback_mail'] ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _header(_pageWidth, logo),
        footer: (context) => _footer(context),
        build: (context) => [
          // 1. Información General del Proyecto
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            child: pw.Text('1.- Datos del Proyecto', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ),
          if (business.isNotEmpty)
            _box(backgroundColor: _white, width: _pageWidth, title: 'Empresa: $business', textStyle: pw.TextStyle(fontSize: 11), mainAxisAlignment: pw.MainAxisAlignment.start),
          if (product.isNotEmpty)
            _box(backgroundColor: _white, width: _pageWidth, title: 'Producto: $product', textStyle: pw.TextStyle(fontSize: 11), mainAxisAlignment: pw.MainAxisAlignment.start),
          if (projectDetail.isNotEmpty)
            _box(backgroundColor: _white, width: _pageWidth, title: 'Detalle del proyecto: $projectDetail', textStyle: pw.TextStyle(fontSize: 11), mainAxisAlignment: pw.MainAxisAlignment.start, fitContent: true),

          pw.SizedBox(height: 10),

          // 2. Información de la Instalación
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Text('1.1 Datos de la Instalación', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ),
          _box(backgroundColor: _white, width: _pageWidth, title: 'Desarrollador: $developer', textStyle: pw.TextStyle(fontSize: 11), mainAxisAlignment: pw.MainAxisAlignment.start),
          _box(backgroundColor: _white, width: _pageWidth, title: 'Correo: $email', textStyle: pw.TextStyle(fontSize: 11), mainAxisAlignment: pw.MainAxisAlignment.start),
          _box(backgroundColor: _white, width: _pageWidth, title: 'Fecha: $date', textStyle: pw.TextStyle(fontSize: 11), mainAxisAlignment: pw.MainAxisAlignment.start),
          _box(backgroundColor: _white, width: _pageWidth, title: 'Commit: $sha', textStyle: pw.TextStyle(fontSize: 11), mainAxisAlignment: pw.MainAxisAlignment.start),
          _box(backgroundColor: _white, width: _pageWidth, title: 'Mensaje: $message', textStyle: pw.TextStyle(fontSize: 11), mainAxisAlignment: pw.MainAxisAlignment.start, fitContent: true),

          pw.SizedBox(height: 15),

          // 2. Lista de Componentes
          pw.Text('1.1.2 Lista de componentes:', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          if (files.isNotEmpty) ...[
            pw.Table(
              border: pw.TableBorder.all(color: _black, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(50),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _lightGrey),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Archivo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Estatus', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Cambios', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  ],
                ),
                ...files.map((file) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_formatString(file['filename'], 40), style: pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(file['status']?.toString() ?? '', style: pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(file['changes']?.toString() ?? '0', style: pw.TextStyle(fontSize: 9))),
                    ],
                  );
                }),
              ],
            ),
          ],

          pw.SizedBox(height: 20),

          // 3. Rollback Plan
          pw.Text('2.- Plan de marcha atrás (Rollback)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
          _box(backgroundColor: _white, width: _pageWidth, title: 'Versión anterior a restaurar (Commit SHA): $rollbackSha', textStyle: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold), mainAxisAlignment: pw.MainAxisAlignment.start),
          if (userRollback.isNotEmpty)
            _box(backgroundColor: _white, width: _pageWidth, title: 'Responsable de rollback: $userRollback${userRollbackMail.isNotEmpty ? "  ($userRollbackMail)" : ""}', textStyle: pw.TextStyle(fontSize: 10), mainAxisAlignment: pw.MainAxisAlignment.start),
          
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: _black, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FixedColumnWidth(100),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _lightGrey),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('#', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Acción de Rollback', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Propietario', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                ],
              ),
              _rollbackRow('1', 'Informar al negocio de la decisión de dar Marcha Atrás.', 'Coord. Producción'),
              _rollbackRow('2', 'Cargar la página de mantenimiento en el sitio web.', 'Infraestructura'),
              _rollbackRow('3', 'Implementación de versión anterior (SHA: $rollbackSha).', 'Desarrollo / DevOps'),
              _rollbackRow('4', 'Disponibilidad del sistema y notificación a usuarios.', 'Coord. Producción'),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.TableRow _rollbackRow(String no, String action, String owner) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(no, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(action, style: pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(owner, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9))),
      ],
    );
  }
}
