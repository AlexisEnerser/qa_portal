import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/app_shell.dart';
import 'automated_controller.dart';

const _kBg = Color(0xFF1E1E2E);
const _kSurface = Color(0xFF2A2A3E);
const _kPrimary = Color(0xFF6C63FF);
const _kRadius = 12.0;

class AutomatedRunScreen extends StatefulWidget {
  const AutomatedRunScreen({super.key});

  @override
  State<AutomatedRunScreen> createState() => _AutomatedRunScreenState();
}

class _AutomatedRunScreenState extends State<AutomatedRunScreen> {
  late final String runId;
  late final String suiteName;
  late final String suiteId;
  late final String projectId;
  late final String projectName;
  late final bool fromHistory;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    runId = args['runId'] as String? ?? '';
    suiteName = args['suiteName'] as String? ?? '';
    suiteId = args['suiteId'] as String? ?? '';
    projectId = args['projectId'] as String? ?? '';
    projectName = args['projectName'] as String? ?? '';
    fromHistory = args['fromHistory'] as bool? ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = AutomatedController.to;
      // Cargar tests de la suite (para tener script_code disponible en análisis IA)
      ctrl.loadTests(suiteId);
      // Cargar resultados inmediatamente (para runs históricos)
      ctrl.loadRunResults(runId);
      // Iniciar polling (se auto-detiene si el run ya terminó)
      ctrl.startPolling(runId);
    });
  }

  @override
  void dispose() {
    AutomatedController.to.stopPolling();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'passed': return Colors.green;
      case 'failed': return Colors.redAccent;
      case 'error': return Colors.orange;
      case 'running': return Colors.amber;
      case 'completed': return Colors.green;
      default: return Colors.white38;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'passed': return Icons.check_circle;
      case 'failed': return Icons.cancel;
      case 'error': return Icons.error;
      case 'skipped': return Icons.skip_next;
      default: return Icons.hourglass_empty;
    }
  }

  void _showFullScreenImage(String url) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                onPressed: () => Get.back(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Ejecución — $suiteName',
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
          onPressed: () {
            AutomatedController.to.stopPolling();
            if (fromHistory) {
              Get.offNamed('/automated/history', arguments: {
                'suiteId': suiteId, 'suiteName': suiteName,
                'projectId': projectId, 'projectName': projectName,
              });
            } else {
              Get.offNamed('/automated/suite', arguments: {
                'suiteId': suiteId, 'suiteName': suiteName,
                'projectId': projectId, 'projectName': projectName,
              });
            }
          },
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Regresar'),
        ),
        const SizedBox(width: 8),
        Obx(() {
          final st = AutomatedController.to.runStatus.value;
          final isDone = st != null && (st.status == 'completed' || st.status == 'failed');
          return OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: isDone ? _kPrimary : Colors.white24,
              side: BorderSide(color: isDone ? _kPrimary : Colors.white12),
            ),
            onPressed: isDone ? () => AutomatedController.to.downloadPdf(runId) : null,
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Exportar PDF'),
          );
        }),
      ],
      child: Obx(() {
        final ctrl = AutomatedController.to;
        final status = ctrl.runStatus.value;
        final isRunning = status == null || status.status == 'pending' || status.status == 'running';

        return Column(
          children: [
            // Progress header
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(_kRadius)),
              child: status == null
                  ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                  : Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isRunning ? Icons.sync : (status.status == 'completed' ? Icons.check_circle : Icons.error),
                              color: _statusColor(status.status), size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isRunning ? 'Ejecutando...' : status.status.toUpperCase(),
                              style: TextStyle(color: _statusColor(status.status), fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (status.total > 0)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: status.total > 0 ? status.completed / status.total : 0,
                              minHeight: 10,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(_statusColor(status.status)),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _statChip('Total', status.total, Colors.white70),
                            _statChip('Completados', status.completed, _kPrimary),
                            _statChip('Pasados', status.passed, Colors.green),
                            _statChip('Fallidos', status.failed, Colors.redAccent),
                            _statChip('Errores', status.error, Colors.orange),
                          ],
                        ),
                      ],
                    ),
            ),

            // Results list
            Expanded(
              child: ctrl.results.isEmpty && isRunning
                  ? const Center(child: Text('Esperando resultados...', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: ctrl.results.length,
                      itemBuilder: (_, i) {
                        final r = ctrl.results[i];
                        return Card(
                          color: _kSurface,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
                          child: ExpansionTile(
                            leading: Icon(_statusIcon(r.status), color: _statusColor(r.status)),
                            title: Text(r.testName, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              '${r.status.toUpperCase()} · ${r.durationMs != null ? "${r.durationMs}ms" : "-"}',
                              style: TextStyle(color: _statusColor(r.status), fontSize: 12),
                            ),
                            children: [
                              if (r.errorMessage != null && r.errorMessage!.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(r.errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'monospace')),
                                ),

                              // Botón analizar con IA (solo para failed/error)
                              if (r.status == 'failed' || r.status == 'error') ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Obx(() {
                                    final isAnalyzing = ctrl.analyzingError[r.id] == true;
                                    final analysis = ctrl.errorAnalysis[r.id];
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (analysis == null)
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.amber,
                                              side: const BorderSide(color: Colors.amber),
                                            ),
                                            onPressed: isAnalyzing ? null : () {
                                              // Buscar el script del test case
                                              final tc = ctrl.tests.firstWhereOrNull((t) => t.id == r.automatedTestCaseId);
                                              ctrl.analyzeError(
                                                r.id, r.testName,
                                                tc?.scriptCode ?? '',
                                                r.errorMessage ?? '',
                                                r.consoleLog,
                                              );
                                            },
                                            icon: isAnalyzing
                                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                                                : const Icon(Icons.auto_awesome, size: 18),
                                            label: Text(isAnalyzing ? 'Analizando...' : 'Analizar con IA'),
                                          ),
                                        if (analysis != null)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                                                    SizedBox(width: 8),
                                                    Text('Análisis IA', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 13)),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                SelectableText(analysis, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    );
                                  }),
                                ),
                              ],

                              if (r.consoleLog != null && r.consoleLog!.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  padding: const EdgeInsets.all(12),
                                  constraints: const BoxConstraints(maxHeight: 150),
                                  decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(8)),
                                  child: SingleChildScrollView(
                                    child: Text(r.consoleLog!, style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                                  ),
                                ),

                              // Galería de screenshots
                              if (r.screenshots.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${r.screenshots.length} captura(s)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 160,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: r.screenshots.length,
                                          itemBuilder: (_, si) {
                                            final url = ctrl.screenshotUrl(r.screenshots[si]);
                                            return GestureDetector(
                                              onTap: () => _showFullScreenImage(url),
                                              child: Container(
                                                width: 240,
                                                margin: const EdgeInsets.only(right: 8),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.white12),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    url,
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (_, child, progress) {
                                                      if (progress == null) return child;
                                                      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary));
                                                    },
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: Icon(Icons.broken_image, color: Colors.white24, size: 32),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}
