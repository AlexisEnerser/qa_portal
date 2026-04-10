import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/app_shell.dart';
import 'automated_controller.dart';

const _kBg = Color(0xFF1E1E2E);
const _kSurface = Color(0xFF2A2A3E);
const _kPrimary = Color(0xFF6C63FF);
const _kRadius = 12.0;

class AutomatedSuitesScreen extends StatefulWidget {
  const AutomatedSuitesScreen({super.key});

  @override
  State<AutomatedSuitesScreen> createState() => _AutomatedSuitesScreenState();
}

class _AutomatedSuitesScreenState extends State<AutomatedSuitesScreen> {
  late final String projectId;
  late final String projectName;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    projectId = args['projectId'] as String? ?? '';
    projectName = args['projectName'] as String? ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AutomatedController.to.loadSuites(projectId);
    });
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: _kSurface,
        title: const Text('Nueva Suite Automatizada', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nombre', labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kPrimary)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)', labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kPrimary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kPrimary),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final ok = await AutomatedController.to.createSuite(projectId, nameCtrl.text, descCtrl.text);
              Get.back();
              if (ok) AutomatedController.to.loadSuites(projectId);
            },
            child: const Text('Crear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'failed': return Colors.redAccent;
      case 'running': return Colors.amber;
      default: return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '$projectName — Pruebas Automatizadas',
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Regresar'),
        ),
      ],
      child: Obx(() {
        final ctrl = AutomatedController.to;
        if (ctrl.isLoading.value && ctrl.suites.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: _kPrimary));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('${ctrl.suites.length} suite(s)', style: const TextStyle(color: Colors.white70)),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text('Nueva Suite', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ctrl.suites.isEmpty
                  ? const Center(child: Text('No hay suites automatizadas', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: ctrl.suites.length,
                      itemBuilder: (_, i) {
                        final s = ctrl.suites[i];
                        final pct = s.lastRunTotal > 0 ? (s.lastRunPassed / s.lastRunTotal * 100).toStringAsFixed(0) : '-';
                        return Card(
                          color: _kSurface,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Icon(Icons.science_outlined, color: _statusColor(s.lastRunStatus)),
                            title: Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${s.testCount} tests · Último run: ${s.lastRunStatus ?? "ninguno"} ($pct%)',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () async {
                                    final ok = await Get.dialog<bool>(AlertDialog(
                                      backgroundColor: _kSurface,
                                      title: const Text('Eliminar suite', style: TextStyle(color: Colors.white)),
                                      content: Text('¿Eliminar "${s.name}"?', style: const TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                          onPressed: () => Get.back(result: true),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ));
                                    if (ok == true) {
                                      await ctrl.deleteSuite(s.id);
                                      ctrl.loadSuites(projectId);
                                    }
                                  },
                                ),
                                const Icon(Icons.chevron_right, color: Colors.white38),
                              ],
                            ),
                            onTap: () => Get.toNamed('/automated/suite', arguments: {
                              'suiteId': s.id,
                              'suiteName': s.name,
                              'projectId': projectId,
                              'projectName': projectName,
                            }),
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
}
