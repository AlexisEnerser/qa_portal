import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../core/widgets/app_shell.dart';
import 'execution_controller.dart';
import 'execution_pdf_controller.dart';

class ExecutionDashboardScreen extends StatefulWidget {
  const ExecutionDashboardScreen({super.key});

  @override
  State<ExecutionDashboardScreen> createState() =>
      _ExecutionDashboardScreenState();
}

class _ExecutionDashboardScreenState
    extends State<ExecutionDashboardScreen> {
  late final Map<String, dynamic> args;
  late final String executionId;
  late final String executionName;
  late final String _projectId;
  late final String _projectName;

  @override
  void initState() {
    super.initState();
    args = Get.arguments as Map<String, dynamic>? ?? {};
    executionId = args['executionId'] as String? ?? '';
    executionName = args['executionName'] as String? ?? '';
    _projectId = args['projectId'] as String? ?? '';
    _projectName = args['projectName'] as String? ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ExecutionController.to.loadDashboard(executionId);
      ExecutionController.to.loadPdfVersions(executionId);
    });
  }

  void _exportPdf() {
    if (!Get.isRegistered<ExecutionPdfController>()) {
      Get.put(ExecutionPdfController());
    }

    final ipCtrl = TextEditingController();
    final enhCtrl = TextEditingController();
    final reqCtrl = TextEditingController();
    final reqPosCtrl = TextEditingController();
    final devCtrl = TextEditingController();
    final tlCtrl = TextEditingController();
    final tlPosCtrl = TextEditingController();
    final coordCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final huCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedLogo = 'ENERSER'.obs;

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Datos para el PDF', style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Logo', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _logoOption(selectedLogo, 'ENERSER'),
                    const SizedBox(width: 12),
                    _logoOption(selectedLogo, 'XIGA'),
                  ]),
                  const SizedBox(height: 12),
                  _pdfField(ipCtrl, 'Dirección IP'),
                  _pdfField(areaCtrl, 'Área'),
                  _pdfField(huCtrl, 'HU Entregable'),
                  _pdfField(enhCtrl, 'Mejoras implementadas', maxLines: 3),
                  const Divider(color: Colors.white12, height: 24),
                  const Text('Firmas', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _pdfField(reqCtrl, 'Solicitante'),
                  _pdfField(reqPosCtrl, 'Cargo del Solicitante'),
                  _pdfField(devCtrl, 'Desarrollador'),
                  _pdfField(tlCtrl, 'Tech Lead'),
                  _pdfField(tlPosCtrl, 'Cargo del Tech Lead'),
                  _pdfField(coordCtrl, 'Coordinador'),
                  // Mostrar error dentro del diálogo si la generación falla
                  Obx(() {
                    final err = ExecutionPdfController.to.error.value;
                    if (err.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(err,
                                style: const TextStyle(color: Color(0xFFEF9A9A), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            onPressed: () async {
              final form = <String, String>{
                'logo': selectedLogo.value,
                'ip': ipCtrl.text.trim(),
                'area': areaCtrl.text.trim(),
                'huEntregable': huCtrl.text.trim(),
                'enhancements': enhCtrl.text.trim(),
                'requestor': reqCtrl.text.trim(),
                'requestorPosition': reqPosCtrl.text.trim(),
                'developer': devCtrl.text.trim(),
                'techlead': tlCtrl.text.trim(),
                'techleadPosition': tlPosCtrl.text.trim(),
                'coordinator': coordCtrl.text.trim(),
              };
              // No cerrar el diálogo — generar dentro del mismo
              ExecutionPdfController.to.error.value = '';
              await ExecutionPdfController.to.generateAndDownload(executionId, form);
              // Solo cerrar si fue exitoso (sin error)
              if (ExecutionPdfController.to.error.value.isEmpty) {
                Get.back();
              }
            },
            child: Obx(() {
              final isLoading = ExecutionPdfController.to.loading.value;
              if (isLoading) {
                return const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,
                  ),
                );
              }
              return const Text('Generar PDF', style: TextStyle(color: Colors.white));
            }),
          ),
        ],
      ),
    );
  }

  Widget _logoOption(RxString selected, String value) {
    return Obx(() {
      final isSelected = selected.value == value;
      return GestureDetector(
        onTap: () => selected.value = value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF6C63FF) : Colors.white24,
            ),
          ),
          child: Text(value, style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 13,
          )),
        ),
      );
    });
  }

  Widget _pdfField(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          isDense: true,
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Dashboard — $executionName',
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
          ),
          onPressed: () => Get.toNamed(
            '/executions',
            arguments: {
              'projectId': _projectId,
              'projectName': _projectName,
            },
          ),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Regresar'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
          ),
          onPressed: () => Get.toNamed(
            '/bugs',
            arguments: {
              'executionId': executionId,
              'executionName': executionName,
              'projectId': _projectId,
              'projectName': _projectName,
            },
          ),
          icon: const Icon(Icons.bug_report_outlined, size: 16),
          label: const Text('Ver Bugs'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF)),
          onPressed: _exportPdf,
          icon: const Icon(Icons.picture_as_pdf, size: 16),
          label: const Text('Exportar PDF', style: TextStyle(color: Colors.white),),
        ),
      ],
      child: Obx(() {
        final ctrl = ExecutionController.to;
        if (ctrl.loading.value) {
          return const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFF6C63FF)));
        }
        if (ctrl.error.value.isNotEmpty) {
          return Center(
            child: Text(ctrl.error.value,
                style: const TextStyle(color: Colors.redAccent)),
          );
        }
        if (ctrl.dashboard.isEmpty) {
          return const Center(
            child: Text('Sin datos de dashboard',
                style: TextStyle(color: Colors.white54)),
          );
        }

        final d = ctrl.dashboard;
        final total = (d['total'] as num?)?.toInt() ?? 0;
        final passed = (d['passed'] as num?)?.toInt() ?? 0;
        final failed = (d['failed'] as num?)?.toInt() ?? 0;
        final blocked = (d['blocked'] as num?)?.toInt() ?? 0;
        final pending = (d['pending'] as num?)?.toInt() ?? 0;
        final completed = passed + failed + blocked;
        final progress = total > 0 ? completed / total : 0.0;

        final byModule =
            d['by_module'] as List<dynamic>? ?? [];
        final byQa = d['by_qa'] as List<dynamic>? ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary stat cards ─────────────────────────────────
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                      label: 'Total',
                      value: total,
                      icon: Icons.list_alt,
                      color: const Color(0xFF6C63FF)),
                  _StatCard(
                      label: 'Pasados',
                      value: passed,
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF4CAF50)),
                  _StatCard(
                      label: 'Fallidos',
                      value: failed,
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFE53935)),
                  _StatCard(
                      label: 'Bloqueados',
                      value: blocked,
                      icon: Icons.block_outlined,
                      color: const Color(0xFFFF9800)),
                  _StatCard(
                      label: 'Pendientes',
                      value: pending,
                      icon: Icons.hourglass_empty_outlined,
                      color: const Color(0xFF607D8B)),
                ],
              ),
              const SizedBox(height: 24),

              // ── Progress bar ───────────────────────────────────────
              _sectionLabel('Progreso general'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$completed de $total completados',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF6C63FF)),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── By module ──────────────────────────────────────────
              if (byModule.isNotEmpty) ...[
                _sectionLabel('Por módulo'),
                const SizedBox(height: 8),
                _ModuleTable(rows: byModule),
                const SizedBox(height: 24),
              ],

              // ── By QA ──────────────────────────────────────────────
              if (byQa.isNotEmpty) ...[
                _sectionLabel('Por QA'),
                const SizedBox(height: 8),
                _QaTable(rows: byQa),
                const SizedBox(height: 24),
              ],

              // ── PDF Versions ───────────────────────────────────────
              Obx(() {
                final versions = ExecutionController.to.pdfVersions;
                if (versions.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Versiones de PDF'),
                    const SizedBox(height: 8),
                    _PdfVersionsTable(
                      rows: versions,
                      executionId: executionId,
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              }),
            ],
          ),
        );
      }),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: TextStyle(
                color: color, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ModuleTable extends StatelessWidget {
  final List<dynamic> rows;

  const _ModuleTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
            const Color(0xFF1E1E2E).withValues(alpha: 0.5)),
        columns: const [
          DataColumn(
              label: Text('Módulo',
                  style: TextStyle(color: Colors.white54))),
          DataColumn(
              label: Text('Total',
                  style: TextStyle(color: Colors.white54))),
          DataColumn(
              label: Text('Pasados',
                  style: TextStyle(color: Color(0xFF4CAF50)))),
          DataColumn(
              label: Text('Fallidos',
                  style: TextStyle(color: Color(0xFFE53935)))),
          DataColumn(
              label: Text('Bloqueados',
                  style: TextStyle(color: Color(0xFFFF9800)))),
          DataColumn(
              label: Text('Pendientes',
                  style: TextStyle(color: Color(0xFF607D8B)))),
        ],
        rows: rows.map((r) {
          final m = r as Map<String, dynamic>? ?? {};
          return DataRow(cells: [
            DataCell(Text(m['module_name'] as String? ?? '—',
                style: const TextStyle(color: Colors.white))),
            DataCell(Text('${m['total'] ?? 0}',
                style: const TextStyle(color: Colors.white70))),
            DataCell(Text('${m['passed'] ?? 0}',
                style:
                    const TextStyle(color: Color(0xFF4CAF50)))),
            DataCell(Text('${m['failed'] ?? 0}',
                style:
                    const TextStyle(color: Color(0xFFE53935)))),
            DataCell(Text('${m['blocked'] ?? 0}',
                style:
                    const TextStyle(color: Color(0xFFFF9800)))),
            DataCell(Text('${m['pending'] ?? 0}',
                style:
                    const TextStyle(color: Color(0xFF607D8B)))),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _QaTable extends StatelessWidget {
  final List<dynamic> rows;

  const _QaTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
            const Color(0xFF1E1E2E).withValues(alpha: 0.5)),
        columns: const [
          DataColumn(
              label:
                  Text('QA', style: TextStyle(color: Colors.white54))),
          DataColumn(
              label: Text('Total',
                  style: TextStyle(color: Colors.white54))),
          DataColumn(
              label: Text('Pasados',
                  style: TextStyle(color: Color(0xFF4CAF50)))),
          DataColumn(
              label: Text('Fallidos',
                  style: TextStyle(color: Color(0xFFE53935)))),
        ],
        rows: rows.map((r) {
          final m = r as Map<String, dynamic>? ?? {};
          return DataRow(cells: [
            DataCell(Text(
                m['qa_name'] as String? ??
                    m['assigned_to'] as String? ??
                    '—',
                style: const TextStyle(color: Colors.white))),
            DataCell(Text('${m['total'] ?? 0}',
                style: const TextStyle(color: Colors.white70))),
            DataCell(Text('${m['passed'] ?? 0}',
                style:
                    const TextStyle(color: Color(0xFF4CAF50)))),
            DataCell(Text('${m['failed'] ?? 0}',
                style:
                    const TextStyle(color: Color(0xFFE53935)))),
          ]);
        }).toList(),
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────

class _PdfVersionsTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String executionId;

  const _PdfVersionsTable({required this.rows, required this.executionId});

  void _openUrl(String url) {
    try {
      final window = globalContext['window'] as JSObject;
      window.callMethodVarArgs('open'.toJS, [url.toJS, '_blank'.toJS]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
            const Color(0xFF1E1E2E).withValues(alpha: 0.5)),
        columns: const [
          DataColumn(label: Text('Versión', style: TextStyle(color: Colors.white54))),
          DataColumn(label: Text('Generado por', style: TextStyle(color: Colors.white54))),
          DataColumn(label: Text('Fecha', style: TextStyle(color: Colors.white54))),
          DataColumn(label: Text('Tamaño', style: TextStyle(color: Colors.white54))),
          DataColumn(label: Text('', style: TextStyle(color: Colors.white54))),
        ],
        rows: rows.map((v) {
          final versionNum = v['version_number'] ?? 0;
          final generatedBy = v['generated_by'] as String? ?? '—';
          final generatedAt = v['generated_at'] as String? ?? '';
          final fileSize = v['file_size'] as int? ?? 0;
          final versionId = v['id'] as String? ?? '';

          String dateStr = '';
          if (generatedAt.isNotEmpty) {
            try {
              final dt = DateTime.parse(generatedAt);
              dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            } catch (_) {
              dateStr = generatedAt;
            }
          }

          final sizeStr = fileSize > 1024 * 1024
              ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
              : '${(fileSize / 1024).toStringAsFixed(0)} KB';

          return DataRow(cells: [
            DataCell(Text('v$versionNum',
                style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w600))),
            DataCell(Text(generatedBy, style: const TextStyle(color: Colors.white))),
            DataCell(Text(dateStr, style: const TextStyle(color: Colors.white70))),
            DataCell(Text(sizeStr, style: const TextStyle(color: Colors.white70))),
            DataCell(
              IconButton(
                icon: const Icon(Icons.download, color: Color(0xFF6C63FF), size: 18),
                tooltip: 'Descargar',
                onPressed: () async {
                  final url = await ExecutionController.to.getPdfDownloadUrl(
                    executionId, versionId,
                  );
                  if (url != null) {
                    _openUrl(url);
                  } else {
                    Get.snackbar('Error', 'No se pudo obtener la URL de descarga',
                        backgroundColor: const Color(0xFFE53935), colorText: Colors.white);
                  }
                },
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}
