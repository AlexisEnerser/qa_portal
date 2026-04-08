import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/app_shell.dart';
import 'bugs_controller.dart';

class BugsScreen extends StatefulWidget {
  const BugsScreen({super.key});

  @override
  State<BugsScreen> createState() => _BugsScreenState();
}

class _BugsScreenState extends State<BugsScreen> {
  late final Map<String, dynamic> args;
  late final String executionId;
  late final String executionName;
  late final String _projectId;
  late final String _projectName;

  String _severity = 'todos';
  String _status = 'todos';

  @override
  void initState() {
    super.initState();
    args = Get.arguments as Map<String, dynamic>? ?? {};
    executionId = args['executionId'] as String? ?? '';
    executionName = args['executionName'] as String? ?? '';
    _projectId = args['projectId'] as String? ?? '';
    _projectName = args['projectName'] as String? ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BugsController.to.loadBugs(executionId);
    });
  }

  void _applyFilters() {
    BugsController.to.loadBugs(
      executionId,
      severity: _severity == 'todos' ? null : _severity,
      status: _status == 'todos' ? null : _status,
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFE53935);
      case 'high':
        return const Color(0xFFFF9800);
      case 'medium':
        return const Color(0xFFFFEB3B);
      case 'low':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return const Color(0xFFE53935);
      case 'in_progress':
        return const Color(0xFFFF9800);
      case 'closed':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Abierto';
      case 'in_progress':
        return 'En progreso';
      case 'closed':
        return 'Cerrado';
      default:
        return status;
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'critical':
        return 'Crítico';
      case 'high':
        return 'Alto';
      case 'medium':
        return 'Medio';
      case 'low':
        return 'Bajo';
      default:
        return severity;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  Future<void> _confirmDelete(String bugId) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Eliminar bug',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Confirmas que deseas eliminar este bug?',
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
          await BugsController.to.deleteBug(bugId, executionId);
      if (!ok) {
        Get.snackbar('Error', 'No se pudo eliminar el bug',
            backgroundColor: const Color(0xFFE53935),
            colorText: Colors.white);
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> bug) {
    Get.dialog(
      _BugEditDialog(
        bug: bug,
        onSave: (body) async {
          final ok = await BugsController.to
              .updateBug(bug['id'].toString(), body);
          if (!ok) {
            Get.snackbar('Error', 'No se pudo actualizar el bug',
                backgroundColor: const Color(0xFFE53935),
                colorText: Colors.white);
          }
        },
      ),
    );
  }

  void _showBugDetail(Map<String, dynamic> bug) {
    final screenshots = (bug['screenshots'] as List<dynamic>?) ?? [];
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: Row(
          children: [
            Expanded(
              child: Text(
                bug['title'] as String? ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () => Get.back(),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  _Badge(label: _severityLabel(bug['severity'] ?? ''), color: _severityColor(bug['severity'] ?? '')),
                  const SizedBox(width: 8),
                  _Badge(label: _statusLabel(bug['status'] ?? ''), color: _statusColor(bug['status'] ?? '')),
                  const Spacer(),
                  Text(_formatDate(bug['created_at'] as String?),
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ]),
                if ((bug['description'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  const Text('Descripción', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(bug['description'] as String, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
                if ((bug['steps_to_reproduce'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  const Text('Pasos para reproducir', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(bug['steps_to_reproduce'] as String, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
                if (screenshots.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Capturas de pantalla (${screenshots.length})',
                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...screenshots.map((s) {
                    final fileName = s['file_name'] as String? ?? '';
                    final imageUrl = '$baseUrl/qa/screenshots/file/$fileName';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, __, ___) => Container(
                            height: 100,
                            color: const Color(0xFF1E1E2E),
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.white24, size: 40),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Bugs — $executionName',
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
          ),
          onPressed: () => Get.offNamed('/execution/run', arguments: {
            'executionId': executionId,
            'projectId': _projectId,
            'projectName': _projectName,
          }),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Regresar'),
        ),
      ],
      child: Column(
        children: [
          // ── Filter row ───────────────────────────────────────────────
          Container(
            color: const Color(0xFF2A2A3E),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Text('Severidad:',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 8),
                _FilterDropdown(
                  value: _severity,
                  items: const {
                    'todos': 'Todos',
                    'critical': 'Crítico',
                    'high': 'Alto',
                    'medium': 'Medio',
                    'low': 'Bajo',
                  },
                  onChanged: (v) {
                    setState(() => _severity = v ?? 'todos');
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 16),
                const Text('Estado:',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 8),
                _FilterDropdown(
                  value: _status,
                  items: const {
                    'todos': 'Todos',
                    'open': 'Abierto',
                    'in_progress': 'En progreso',
                    'closed': 'Cerrado',
                  },
                  onChanged: (v) {
                    setState(() => _status = v ?? 'todos');
                    _applyFilters();
                  },
                ),
              ],
            ),
          ),

          // ── Bug list ─────────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              final ctrl = BugsController.to;
              if (ctrl.loading.value) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF)));
              }
              if (ctrl.error.value.isNotEmpty) {
                return Center(
                  child: Text(ctrl.error.value,
                      style:
                          const TextStyle(color: Colors.redAccent)),
                );
              }
              if (ctrl.bugs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bug_report_outlined,
                          size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('No hay bugs registrados',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ctrl.bugs.length,
                itemBuilder: (_, i) {
                  final bug = ctrl.bugs[i];
                  final severity =
                      bug['severity'] as String? ?? 'low';
                  final bugStatus =
                      bug['status'] as String? ?? 'open';
                  final title =
                      bug['title'] as String? ?? 'Sin título';
                  final description =
                      bug['description'] as String? ?? '';
                  final createdAt =
                      bug['created_at'] as String?;
                  final bugId = bug['id']?.toString() ?? '';

                  return GestureDetector(
                    onTap: () => _showBugDetail(bug),
                    child: Card(
                    color: const Color(0xFF2A2A3E),
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Severity badge
                          Container(
                            width: 8,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _severityColor(severity),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _Badge(
                                      label:
                                          _severityLabel(severity),
                                      color: _severityColor(severity),
                                    ),
                                    const SizedBox(width: 8),
                                    _Badge(
                                      label: _statusLabel(bugStatus),
                                      color: _statusColor(bugStatus),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDate(createdAt),
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                                if (description.isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 4),
                                    child: Text(
                                      description,
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Actions
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.white54, size: 20),
                                tooltip: 'Editar',
                                onPressed: () =>
                                    _showEditDialog(bug),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Color(0xFFE53935),
                                    size: 20),
                                tooltip: 'Eliminar',
                                onPressed: () =>
                                    _confirmDelete(bugId),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ));
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      dropdownColor: const Color(0xFF2A2A3E),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      underline: const SizedBox.shrink(),
      items: items.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bug edit dialog
// ─────────────────────────────────────────────────────────────────────────────

class _BugEditDialog extends StatefulWidget {
  final Map<String, dynamic> bug;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _BugEditDialog({required this.bug, required this.onSave});

  @override
  State<_BugEditDialog> createState() => _BugEditDialogState();
}

class _BugEditDialogState extends State<_BugEditDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _stepsCtrl;
  late String _severity;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
        text: widget.bug['title'] as String? ?? '');
    _descCtrl = TextEditingController(
        text: widget.bug['description'] as String? ?? '');
    _stepsCtrl = TextEditingController(
        text: widget.bug['steps_to_reproduce'] as String? ?? '');
    _severity = widget.bug['severity'] as String? ?? 'medium';
    _status = widget.bug['status'] as String? ?? 'open';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A3E),
      title: const Text('Editar bug',
          style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_titleCtrl, 'Título *'),
              const SizedBox(height: 12),
              _field(_descCtrl, 'Descripción', maxLines: 3),
              const SizedBox(height: 12),
              _field(_stepsCtrl, 'Pasos para reproducir', maxLines: 3),
              const SizedBox(height: 12),
              _label('Severidad'),
              const SizedBox(height: 6),
              _darkDropdown<String>(
                value: _severity,
                items: const {
                  'critical': 'Crítico',
                  'high': 'Alto',
                  'medium': 'Medio',
                  'low': 'Bajo',
                },
                onChanged: (v) =>
                    setState(() => _severity = v ?? _severity),
              ),
              const SizedBox(height: 12),
              _label('Estado'),
              const SizedBox(height: 6),
              _darkDropdown<String>(
                value: _status,
                items: const {
                  'open': 'Abierto',
                  'in_progress': 'En progreso',
                  'closed': 'Cerrado',
                },
                onChanged: (v) =>
                    setState(() => _status = v ?? _status),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Get.back(),
          child: const Text('Cancelar',
              style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF)),
          onPressed: _saving
              ? null
              : () async {
                  if (_titleCtrl.text.trim().isEmpty) {
                    Get.snackbar('Error', 'El título es requerido',
                        backgroundColor: const Color(0xFFE53935),
                        colorText: Colors.white);
                    return;
                  }
                  setState(() => _saving = true);
                  await widget.onSave({
                    'title': _titleCtrl.text.trim(),
                    'description': _descCtrl.text.trim(),
                    'steps_to_reproduce': _stepsCtrl.text.trim(),
                    'severity': _severity,
                    'status': _status,
                  });
                  setState(() => _saving = false);
                  Get.back();
                },
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF6C63FF))),
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(color: Colors.white54, fontSize: 12));
  }

  Widget _darkDropdown<T>({
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: const Color(0xFF2A2A3E),
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF6C63FF))),
        filled: true,
        fillColor: Color(0xFF1E1E2E),
      ),
      items: items.entries
          .map((e) => DropdownMenuItem<T>(
              value: e.key,
              child: Text(e.value,
                  style: const TextStyle(color: Colors.white))))
          .toList(),
      onChanged: onChanged,
    );
  }
}
