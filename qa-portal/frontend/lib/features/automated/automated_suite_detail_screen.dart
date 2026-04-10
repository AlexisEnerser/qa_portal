import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/app_shell.dart';
import 'automated_controller.dart';

const _kBg = Color(0xFF1E1E2E);
const _kSurface = Color(0xFF2A2A3E);
const _kPrimary = Color(0xFF6C63FF);
const _kRadius = 12.0;

class AutomatedSuiteDetailScreen extends StatefulWidget {
  const AutomatedSuiteDetailScreen({super.key});

  @override
  State<AutomatedSuiteDetailScreen> createState() => _AutomatedSuiteDetailScreenState();
}

class _AutomatedSuiteDetailScreenState extends State<AutomatedSuiteDetailScreen> {
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
      AutomatedController.to.loadTests(suiteId);
    });
  }

  void _showRunDialog() {
    final envCtrl = TextEditingController();
    final verCtrl = TextEditingController();
    Get.dialog(AlertDialog(
      backgroundColor: _kSurface,
      title: const Text('Ejecutar Suite', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: envCtrl, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Ambiente (opcional)', labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kPrimary)))),
          const SizedBox(height: 12),
          TextField(controller: verCtrl, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Versión (opcional)', labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kPrimary)))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kPrimary),
          onPressed: () async {
            Get.back();
            final runId = await AutomatedController.to.startRun(
              suiteId, environment: envCtrl.text, version: verCtrl.text);
            if (runId != null) {
              Get.toNamed('/automated/run', arguments: {
                'runId': runId, 'suiteName': suiteName,
                'suiteId': suiteId, 'projectId': projectId, 'projectName': projectName,
              });
            }
          },
          child: const Text('Ejecutar', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '$projectName — $suiteName',
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
          onPressed: () => Get.offNamed('/automated/suites', arguments: {'projectId': projectId, 'projectName': projectName}),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Regresar'),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => Get.toNamed('/automated/history', arguments: {
            'suiteId': suiteId, 'suiteName': suiteName,
            'projectId': projectId, 'projectName': projectName,
          }),
          icon: const Icon(Icons.history, color: Colors.white70, size: 18),
          label: const Text('Historial', style: TextStyle(color: Colors.white70)),
        ),
      ],
      child: Obx(() {
        final ctrl = AutomatedController.to;
        if (ctrl.isLoading.value && ctrl.tests.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: _kPrimary));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('${ctrl.tests.length} test(s)', style: const TextStyle(color: Colors.white70)),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: ctrl.tests.isEmpty ? null : _showRunDialog,
                    icon: const Icon(Icons.play_arrow, size: 18, color: Colors.white),
                    label: const Text('Ejecutar Suite', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                    onPressed: () => Get.toNamed('/automated/test/form', arguments: {
                      'suiteId': suiteId, 'suiteName': suiteName,
                      'projectId': projectId, 'projectName': projectName,
                    }),
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text('Nuevo Test', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ctrl.tests.isEmpty
                  ? const Center(child: Text('No hay tests en esta suite', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: ctrl.tests.length,
                      itemBuilder: (_, i) {
                        final t = ctrl.tests[i];
                        return Card(
                          color: _kSurface,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Icon(
                              t.isActive ? Icons.check_circle_outline : Icons.block,
                              color: t.isActive ? _kPrimary : Colors.white38,
                            ),
                            title: Text(t.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              t.targetUrl ?? 'Sin URL',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (t.sourceTestCaseId != null)
                                  const Tooltip(
                                    message: 'Clonado desde test manual',
                                    child: Icon(Icons.copy_all, color: Colors.amber, size: 18),
                                  ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () async {
                                    await ctrl.deleteTest(t.id);
                                    ctrl.loadTests(suiteId);
                                  },
                                ),
                              ],
                            ),
                            onTap: () => Get.toNamed('/automated/test/form', arguments: {
                              'suiteId': suiteId, 'suiteName': suiteName,
                              'projectId': projectId, 'projectName': projectName,
                              'testId': t.id, 'testName': t.name,
                              'scriptCode': t.scriptCode, 'targetUrl': t.targetUrl,
                              'description': t.description,
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
