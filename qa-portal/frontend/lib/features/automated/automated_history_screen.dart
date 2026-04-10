import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/app_shell.dart';
import 'automated_controller.dart';

const _kSurface = Color(0xFF2A2A3E);
const _kPrimary = Color(0xFF6C63FF);
const _kRadius = 12.0;

class AutomatedHistoryScreen extends StatefulWidget {
  const AutomatedHistoryScreen({super.key});

  @override
  State<AutomatedHistoryScreen> createState() => _AutomatedHistoryScreenState();
}

class _AutomatedHistoryScreenState extends State<AutomatedHistoryScreen> {
  late final String suiteId;
  late final String suiteName;
  late final String projectId;
  late final String projectName;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    suiteId = args['suiteId'] as String? ?? '';
    suiteName = args['suiteName'] as String? ?? '';
    projectId = args['projectId'] as String? ?? '';
    projectName = args['projectName'] as String? ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AutomatedController.to.loadRuns(suiteId);
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'failed': return Colors.redAccent;
      case 'running': return Colors.amber;
      case 'cancelled': return Colors.grey;
      default: return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Historial — $suiteName',
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
          onPressed: () => Get.offNamed('/automated/suite', arguments: {
            'suiteId': suiteId, 'suiteName': suiteName,
            'projectId': projectId, 'projectName': projectName,
          }),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Regresar'),
        ),
      ],
      child: Obx(() {
        final ctrl = AutomatedController.to;
        if (ctrl.isLoading.value && ctrl.runs.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: _kPrimary));
        }
        if (ctrl.runs.isEmpty) {
          return const Center(child: Text('No hay ejecuciones previas', style: TextStyle(color: Colors.white38)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ctrl.runs.length,
          itemBuilder: (_, i) {
            final r = ctrl.runs[i];
            final pct = r.total > 0 ? (r.passed / r.total * 100).toStringAsFixed(0) : '-';
            return Card(
              color: _kSurface,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Icon(Icons.play_circle_outline, color: _statusColor(r.status)),
                title: Text(
                  '${r.status.toUpperCase()} · $pct% pasados',
                  style: TextStyle(color: _statusColor(r.status), fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${r.version ?? "sin versión"} · ${r.environment ?? "sin ambiente"} · ${r.startedAt ?? ""}\n'
                  'Total: ${r.total} | Pasados: ${r.passed} | Fallidos: ${r.failed} | Errores: ${r.error}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () {
                  ctrl.loadRunResults(r.id);
                  Get.toNamed('/automated/run', arguments: {
                    'runId': r.id, 'suiteName': suiteName,
                    'suiteId': suiteId, 'projectId': projectId, 'projectName': projectName,
                    'fromHistory': true,
                  });
                },
              ),
            );
          },
        );
      }),
    );
  }
}
