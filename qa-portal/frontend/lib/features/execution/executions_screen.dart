import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/models/execution.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/widgets/app_shell.dart';
import 'execution_controller.dart';

class ExecutionsScreen extends StatefulWidget {
  const ExecutionsScreen({super.key});

  @override
  State<ExecutionsScreen> createState() => _ExecutionsScreenState();
}

class _ExecutionsScreenState extends State<ExecutionsScreen> {
  late final Map<String, dynamic> args;
  late final String projectId;
  late final String projectName;

  @override
  void initState() {
    super.initState();
    args = Get.arguments as Map<String, dynamic>? ?? {};
    projectId = args['projectId'] as String? ?? '';
    projectName = args['projectName'] as String? ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ExecutionController.to.loadExecutions(projectId);
    });
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final versionCtrl = TextEditingController();
    final envCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedModuleIds = <String>{}.obs;

    // Load modules for this project
    ExecutionController.to.loadProjectModules(projectId);

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text(
          'Nueva sesión de ejecución',
          style: TextStyle(color: Colors.white),
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogField(nameCtrl, 'Nombre *', required: true),
                  const SizedBox(height: 12),
                  _dialogField(versionCtrl, 'Versión (ej. 1.0.0)'),
                  const SizedBox(height: 12),
                  _dialogField(envCtrl, 'Ambiente (ej. staging)', required: true),
                  const SizedBox(height: 16),
                  const Text(
                    'Módulos a evaluar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(() {
                    final modules = ExecutionController.to.projectModules;
                    if (modules.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No hay módulos disponibles',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Select all / Deselect all
                        Row(
                          children: [
                            Obx(() {
                              final allSelected = selectedModuleIds.length == modules.length && modules.isNotEmpty;
                              return Checkbox(
                                value: allSelected,
                                tristate: true,
                                onChanged: (_) {
                                  if (selectedModuleIds.length == modules.length) {
                                    selectedModuleIds.clear();
                                  } else {
                                    selectedModuleIds.assignAll(
                                      modules.map((m) => m['id'].toString()),
                                    );
                                  }
                                },
                                activeColor: const Color(0xFF6C63FF),
                                checkColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                              );
                            }),
                            const Text(
                              'Seleccionar todos',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 1),
                        // Module list
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: modules.length,
                            itemBuilder: (_, i) {
                              final mod = modules[i];
                              final modId = mod['id'].toString();
                              return Obx(() => CheckboxListTile(
                                    dense: true,
                                    value: selectedModuleIds.contains(modId),
                                    onChanged: (v) {
                                      if (v == true) {
                                        selectedModuleIds.add(modId);
                                      } else {
                                        selectedModuleIds.remove(modId);
                                      }
                                    },
                                    title: Text(
                                      mod['name'] as String? ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: mod['description'] != null &&
                                            (mod['description'] as String).isNotEmpty
                                        ? Text(
                                            mod['description'] as String,
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    activeColor: const Color(0xFF6C63FF),
                                    checkColor: Colors.white,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                  ));
                            },
                          ),
                        ),
                      ],
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
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF)),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (selectedModuleIds.isEmpty) {
                Get.snackbar(
                  'Atención',
                  'Selecciona al menos un módulo',
                  backgroundColor: const Color(0xFFFF9800),
                  colorText: Colors.white,
                );
                return;
              }
              Get.back();
              final ok = await ExecutionController.to.createExecution(
                projectId,
                nameCtrl.text.trim(),
                versionCtrl.text.trim(),
                envCtrl.text.trim(),
                moduleIds: selectedModuleIds.toList(),
              );
              if (!ok) {
                Get.snackbar('Error', 'No se pudo crear la sesión',
                    backgroundColor: const Color(0xFFE53935),
                    colorText: Colors.white);
              }
            },
            child: const Text('Crear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label, {
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF6C63FF))),
        errorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFE53935))),
        focusedErrorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFE53935))),
      ),
      validator: required
          ? (v) =>
              (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
          : null,
    );
  }

  Future<void> _confirmFinish(String executionId) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Finalizar sesión',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Confirmas que deseas finalizar esta sesión? No podrás registrar más resultados.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935)),
            onPressed: () => Get.back(result: true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok =
          await ExecutionController.to.finishExecution(executionId);
      if (!ok) {
        Get.snackbar('Error', 'No se pudo finalizar la sesión',
            backgroundColor: const Color(0xFFE53935),
            colorText: Colors.white);
      }
    }
  }

  Future<void> _confirmDelete(String executionId) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Eliminar sesión',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta sesión? Se borrarán todos los resultados, capturas y bugs asociados. Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935)),
            onPressed: () => Get.back(result: true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok =
          await ExecutionController.to.deleteExecution(executionId);
      if (ok) {
        Get.snackbar('Listo', 'Sesión eliminada',
            backgroundColor: const Color(0xFF4CAF50),
            colorText: Colors.white);
      } else {
        Get.snackbar('Error', 'No se pudo eliminar la sesión',
            backgroundColor: const Color(0xFFE53935),
            colorText: Colors.white);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Sesiones — $projectName',
      actions: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF)),
          onPressed: _showCreateDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nueva sesión', style: TextStyle(color: Colors.white)),
        ),
      ],
      child: Obx(() {
        final ctrl = ExecutionController.to;
        if (ctrl.loading.value) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF6C63FF)));
        }
        if (ctrl.error.value.isNotEmpty) {
          return Center(
            child: Text(ctrl.error.value,
                style: const TextStyle(color: Colors.redAccent)),
          );
        }
        if (ctrl.executions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.playlist_play,
                    size: 64, color: Colors.white24),
                SizedBox(height: 16),
                Text('No hay sesiones de ejecución',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 16)),
                SizedBox(height: 8),
                Text('Presiona "Nueva sesión" para comenzar',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ctrl.executions.length,
          itemBuilder: (_, i) => _ExecutionCard(
            exec: ctrl.executions[i],
            projectId: projectId,
            projectName: projectName,
            onFinish: _confirmFinish,
            onDelete: _confirmDelete,
            isAdmin: AuthController.to.user.value?.isAdmin ?? false,
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ExecutionCard extends StatelessWidget {
  final TestExecutionSummary exec;
  final String projectId;
  final String projectName;
  final Future<void> Function(String) onFinish;
  final Future<void> Function(String) onDelete;
  final bool isAdmin;

  const _ExecutionCard({
    required this.exec,
    required this.projectId,
    required this.projectName,
    required this.onFinish,
    required this.onDelete,
    required this.isAdmin,
  });

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy HH:mm')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed =
        exec.passed + exec.failed + exec.blocked + exec.notApplicable;
    final progress =
        exec.total > 0 ? completed / exec.total : 0.0;
    final isFinished = exec.finishedAt != null;

    return Card(
      color: const Color(0xFF2A2A3E),
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    exec.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (isFinished)
                  const Chip(
                    label: Text('Finalizada',
                        style:
                            TextStyle(color: Colors.white, fontSize: 11)),
                    backgroundColor: Color(0xFF607D8B),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Meta ───────────────────────────────────────────────────
            Wrap(
              spacing: 16,
              children: [
                if (exec.version != null)
                  _meta(Icons.tag, 'v${exec.version}'),
                _meta(Icons.computer, exec.environment),
                _meta(
                    Icons.calendar_today, _formatDate(exec.startedAt)),
              ],
            ),
            const SizedBox(height: 12),
            // ── Progress bar ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF6C63FF)),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$completed / ${exec.total}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Status chips ───────────────────────────────────────────
            Wrap(
              spacing: 8,
              children: [
                _statusChip(
                    '${exec.passed} Pasados', const Color(0xFF4CAF50)),
                _statusChip(
                    '${exec.failed} Fallidos', const Color(0xFFE53935)),
                _statusChip('${exec.blocked} Bloqueados',
                    const Color(0xFFFF9800)),
                _statusChip('${exec.pending} Pendientes',
                    const Color(0xFF607D8B)),
              ],
            ),
            const SizedBox(height: 12),
            // ── Action buttons ─────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isFinished)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF)),
                    onPressed: () => Get.toNamed(
                      '/execution/run',
                      arguments: {
                        'executionId': exec.id,
                        'projectId': projectId,
                        'projectName': projectName,
                      },
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Continuar', style: TextStyle(color: Colors.white),),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: () => Get.toNamed(
                    '/execution/dashboard',
                    arguments: {
                      'executionId': exec.id,
                      'executionName': exec.name,
                      'projectId': projectId,
                      'projectName': projectName,
                    },
                  ),
                  icon: const Icon(Icons.bar_chart, size: 18),
                  label: const Text('Dashboard'),
                ),
                if (!isFinished)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                      side: const BorderSide(color: Color(0xFFE53935)),
                    ),
                    onPressed: () => onFinish(exec.id),
                    icon: const Icon(Icons.stop_circle_outlined,
                        size: 18),
                    label: const Text('Finalizar'),
                  ),
                if (isAdmin)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                      side: const BorderSide(color: Color(0xFFE53935)),
                    ),
                    onPressed: () => onDelete(exec.id),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Eliminar', style: TextStyle(color: Colors.white),),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white38),
        const SizedBox(width: 4),
        Text(text,
            style:
                const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
