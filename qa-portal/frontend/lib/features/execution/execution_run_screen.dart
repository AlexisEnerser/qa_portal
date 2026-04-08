import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/api/api_client.dart';
import '../../core/models/execution.dart';
import '../../core/widgets/app_shell.dart';
import 'execution_controller.dart';
import 'screen_capture_service.dart';

class ExecutionRunScreen extends StatefulWidget {
  const ExecutionRunScreen({super.key});

  @override
  State<ExecutionRunScreen> createState() => _ExecutionRunScreenState();
}

class _ExecutionRunScreenState extends State<ExecutionRunScreen> {
  late final Map<String, dynamic> args;
  late final String executionId;
  late final String projectName;
  late final String _projectId;

  @override
  void initState() {
    super.initState();
    args = Get.arguments as Map<String, dynamic>? ?? {};
    executionId = args['executionId'] as String? ?? '';
    projectName = args['projectName'] as String? ?? '';
    _projectId = args['projectId'] as String? ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ExecutionController.to.loadExecution(executionId);
      ExecutionController.to.loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ctrl = ExecutionController.to;
      final exec = ctrl.currentExecution.value;
      final execName = exec?.name ?? 'Ejecución';

      return AppShell(
        title: '$projectName — $execName',
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
            ),
            onPressed: () => Get.offNamed('/executions', arguments: {
              'projectId': _projectId,
              'projectName': projectName,
            }),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Regresar'),
          ),
          TextButton.icon(
            onPressed: () => Get.toNamed(
              '/execution/dashboard',
              arguments: {
                'executionId': executionId,
                'executionName': execName,
                'projectId': _projectId,
                'projectName': projectName,
              },
            ),
            icon: const Icon(Icons.bar_chart, color: Colors.white70, size: 18),
            label: const Text('Dashboard',
                style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () {
              Get.toNamed('/execution/dashboard', arguments: {
                'executionId': executionId,
                'executionName': ctrl.currentExecution.value?.name ?? '',
                'projectId': _projectId,
                'projectName': projectName,
              });
            },
            icon:
                const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
            label: const Text('Exportar PDF',
                style: TextStyle(color: Colors.white)),
          ),
        ],
        child: ctrl.loading.value
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
            : Row(
                children: [
                  // ── Left panel ─────────────────────────────────────────
                  _LeftPanel(executionId: executionId),
                  // ── Right panel ────────────────────────────────────────
                  Expanded(
                    child: Obx(() {
                      final selected = ctrl.selectedResult.value;
                      if (selected == null) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app,
                                  size: 64, color: Colors.white24),
                              SizedBox(height: 16),
                              Text('Selecciona un caso de prueba',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 16)),
                            ],
                          ),
                        );
                      }
                      return _ResultDetailPanel(
                        key: ValueKey(selected.id),
                        result: selected,
                        executionId: executionId,
                      );
                    }),
                  ),
                ],
              ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Left panel — grouped test case list
// ─────────────────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final String executionId;

  const _LeftPanel({required this.executionId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      color: const Color(0xFF2A2A3E),
      child: Obx(() {
        final results = ExecutionController.to.results;
        if (results.isEmpty) {
          return const Center(
            child: Text('Sin casos de prueba',
                style: TextStyle(color: Colors.white54)),
          );
        }

        // Progress calculation
        final total = results.length;
        final completed = results.where((r) =>
            r.status == 'passed' ||
            r.status == 'failed' ||
            r.status == 'blocked' ||
            r.status == 'not_applicable').length;
        final progress = total > 0 ? completed / total : 0.0;

        // Group by module
        final Map<String, List<ExecutionResult>> grouped = {};
        for (final r in results) {
          final module =
              r.testCase?['module_name'] as String? ?? 'Sin módulo';
          grouped.putIfAbsent(module, () => []).add(r);
        }

        final modules = grouped.keys.toList();

        return Column(
          children: [
            // Progress bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$completed / $total',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Module groups
            Expanded(
              child: ListView.builder(
                itemCount: modules.length,
                itemBuilder: (_, i) {
                  final module = modules[i];
                  final items = grouped[module]!;
                  return _ModuleGroup(module: module, results: items);
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ModuleGroup extends StatefulWidget {
  final String module;
  final List<ExecutionResult> results;

  const _ModuleGroup({required this.module, required this.results});

  @override
  State<_ModuleGroup> createState() => _ModuleGroupState();
}

class _ModuleGroupState extends State<_ModuleGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Module header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E1E2E).withValues(alpha: 0.5),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: Colors.white54,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.module,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
                Text(
                  '${widget.results.length}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.results.map((r) => _TestCaseItem(result: r)),
      ],
    );
  }
}

class _TestCaseItem extends StatelessWidget {
  final ExecutionResult result;

  const _TestCaseItem({required this.result});

  Color _statusColor(String status) {
    switch (status) {
      case 'passed':
        return const Color(0xFF4CAF50);
      case 'failed':
        return const Color(0xFFE53935);
      case 'blocked':
        return const Color(0xFFFF9800);
      case 'not_applicable':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF607D8B);
    }
  }

  String _initials(String? assignedTo) {
    if (assignedTo == null || assignedTo.isEmpty) return '?';
    final parts = assignedTo.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return assignedTo.substring(0, assignedTo.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ExecutionController.to;
    final title =
        result.testCase?['title'] as String? ?? result.testCaseId;

    return Obx(() {
      final selected = ctrl.selectedResult.value?.id == result.id;
      return InkWell(
        onTap: () => ctrl.selectResult(result),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                : Colors.transparent,
            border: selected
                ? const Border(
                    left: BorderSide(color: Color(0xFF6C63FF), width: 3))
                : const Border(
                    left: BorderSide(color: Colors.transparent, width: 3)),
          ),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _statusColor(result.status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              // Title
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Assignee badge
              if (result.assignedTo != null)
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _initials(result.assignedTo),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right panel — result detail
// ─────────────────────────────────────────────────────────────────────────────

class _ResultDetailPanel extends StatefulWidget {
  final ExecutionResult result;
  final String executionId;

  const _ResultDetailPanel({
    super.key,
    required this.result,
    required this.executionId,
  });

  @override
  State<_ResultDetailPanel> createState() => _ResultDetailPanelState();
}

class _ResultDetailPanelState extends State<_ResultDetailPanel> {
  late TextEditingController _notesCtrl;
  late String _currentStatus;
  String? _selectedAssignee;
  bool _saving = false;
  final ScreenCaptureService _captureService = ScreenCaptureService();
  bool _capturing = false;

  // Timer state
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timerTick;
  int _accumulatedSeconds = 0; // Previously saved duration
  final _elapsedDisplay = '00:00:00'.obs;

  @override
  void initState() {
    super.initState();
    _notesCtrl =
        TextEditingController(text: widget.result.notes ?? '');
    _currentStatus = widget.result.status;
    _selectedAssignee = widget.result.assignedTo;
    _accumulatedSeconds = widget.result.durationSeconds ?? 0;
    _updateElapsedDisplay();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _captureService.stop();
    _timerTick?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _startTimer() {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
      _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateElapsedDisplay();
      });
    }
  }

  void _stopTimer() {
    _stopwatch.stop();
    _timerTick?.cancel();
    _timerTick = null;
  }

  int get _totalSeconds => _accumulatedSeconds + _stopwatch.elapsed.inSeconds;

  void _updateElapsedDisplay() {
    final total = _totalSeconds;
    final h = (total ~/ 3600).toString().padLeft(2, '0');
    final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    _elapsedDisplay.value = '$h:$m:$s';
  }

  Future<void> _sendDuration() async {
    final total = _totalSeconds;
    if (total > 0) {
      await ExecutionController.to.updateResult(
        widget.executionId,
        widget.result.id,
        durationSeconds: total,
      );
    }
  }

  Future<void> _setStatus(String status) async {
    setState(() => _currentStatus = status);
    // Stop timer and send accumulated duration when status changes
    _stopTimer();
    await _sendDuration();
    await ExecutionController.to.updateResult(
      widget.executionId,
      widget.result.id,
      status: status,
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    await _sendDuration();
    await ExecutionController.to.updateResult(
      widget.executionId,
      widget.result.id,
      assignedTo: _selectedAssignee,
      notes: _notesCtrl.text,
    );
    setState(() => _saving = false);
    Get.snackbar('Guardado', 'Cambios guardados correctamente',
        backgroundColor: const Color(0xFF4CAF50), colorText: Colors.white);
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final file in result.files) {
      if (file.bytes == null) continue;
      final ok = await ExecutionController.to.uploadScreenshot(
        widget.result.id,
        file.bytes!,
        file.name,
      );
      if (!ok) {
        Get.snackbar('Error', 'No se pudo subir ${file.name}',
            backgroundColor: const Color(0xFFE53935), colorText: Colors.white);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.result.testCase ?? {};
    final title = tc['title'] as String? ?? widget.result.testCaseId;
    final preconditions = tc['preconditions'] as String? ?? '';
    final steps = tc['steps'] as List<dynamic>? ?? [];

    return Container(
      color: const Color(0xFF1E1E2E),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────────────────
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ── Preconditions ──────────────────────────────────────────
            if (preconditions.isNotEmpty) ...[
              _sectionLabel('Precondiciones'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(preconditions,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
              ),
              const SizedBox(height: 20),
            ],

            // ── Steps table ────────────────────────────────────────────
            if (steps.isNotEmpty) ...[
              _sectionLabel('Pasos'),
              const SizedBox(height: 8),
              _StepsTable(steps: steps),
              const SizedBox(height: 20),
            ],

            // ── Assignee dropdown ──────────────────────────────────────
            _sectionLabel('Asignado a'),
            const SizedBox(height: 8),
            Obx(() {
              final users = ExecutionController.to.qaUsers;
              // Ensure selected value exists in the list
              final validValue = users.any((u) => u['id']?.toString() == _selectedAssignee)
                  ? _selectedAssignee
                  : null;
              return DropdownButtonFormField<String>(
                value: validValue,
                dropdownColor: const Color(0xFF2A2A3E),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6C63FF))),
                  filled: true,
                  fillColor: Color(0xFF2A2A3E),
                ),
                hint: const Text('Sin asignar',
                    style: TextStyle(color: Colors.white54)),
                items: [
                  ...users.map((u) {
                    final id = u['id']?.toString() ?? '';
                    final name = u['name'] as String? ?? id;
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(name,
                          style: const TextStyle(color: Colors.white)),
                    );
                  }),
                ],
                onChanged: (v) => setState(() => _selectedAssignee = v),
              );
            }),
            const SizedBox(height: 20),

            // ── Notes ──────────────────────────────────────────────────
            _sectionLabel('Notas'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Observaciones, evidencias, etc.',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6C63FF))),
                filled: true,
                fillColor: Color(0xFF2A2A3E),
              ),
            ),
            const SizedBox(height: 20),

            // ── Status buttons ─────────────────────────────────────────
            _sectionLabel('Estado'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusBtn('passed', 'Pasó', const Color(0xFF4CAF50)),
                _statusBtn('failed', 'Falló', const Color(0xFFE53935)),
                _statusBtn(
                    'blocked', 'Bloqueado', const Color(0xFFFF9800)),
                _statusBtn('not_applicable', 'No Aplica',
                    const Color(0xFF9E9E9E)),
              ],
            ),
            const SizedBox(height: 20),

            // ── Save button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _saveChanges,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                label: Text(_saving ? 'Guardando...' : 'Guardar cambios', style: TextStyle(color: Colors.white),),
              ),
            ),
            const SizedBox(height: 24),

            // ── Screenshots ────────────────────────────────────────────
            Row(
              children: [
                _sectionLabel('Capturas de pantalla'),
                const SizedBox(width: 12),
                // Timer display
                Obx(() => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _stopwatch.isRunning
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                        : const Color(0xFF2A2A3E),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _stopwatch.isRunning
                          ? const Color(0xFF4CAF50)
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _stopwatch.isRunning ? Icons.timer : Icons.timer_outlined,
                        size: 14,
                        color: _stopwatch.isRunning ? const Color(0xFF4CAF50) : Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _elapsedDisplay.value,
                        style: TextStyle(
                          color: _stopwatch.isRunning ? const Color(0xFF4CAF50) : Colors.white54,
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
                const Spacer(),
                if (_capturing) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () async {
                      final bytes = await _captureService.takeScreenshot();
                      if (bytes != null) {
                        final name = 'captura_${DateTime.now().millisecondsSinceEpoch}.png';
                        await ExecutionController.to.uploadScreenshot(
                          widget.result.id, bytes, name,
                        );
                      }
                    },
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Tomar captura', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                      side: const BorderSide(color: Color(0xFFE53935)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () {
                      _captureService.stop();
                      _stopTimer();
                      _sendDuration();
                      setState(() => _capturing = false);
                    },
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Detener', style: TextStyle(fontSize: 12)),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6C63FF),
                      side: const BorderSide(color: Color(0xFF6C63FF)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () async {
                      final ok = await _captureService.start();
                      if (ok) {
                        _startTimer();
                        setState(() => _capturing = true);
                      } else {
                        Get.snackbar('Error', 'No se pudo iniciar la captura de pantalla',
                            backgroundColor: const Color(0xFFE53935),
                            colorText: Colors.white);
                      }
                    },
                    icon: const Icon(Icons.screenshot_monitor, size: 16),
                    label: const Text('Iniciar captura', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6C63FF),
                      side: const BorderSide(color: Color(0xFF6C63FF)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _pickAndUpload,
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text('Subir imagen', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              final shots = ExecutionController.to.screenshots;
              if (shots.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Sin capturas',
                      style: TextStyle(color: Colors.white38)),
                );
              }
              return SizedBox(
                height: 120,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: shots.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final item = shots.removeAt(oldIndex);
                    shots.insert(newIndex, item);
                    ExecutionController.to.reorderScreenshots(widget.result.id);
                  },
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 4,
                      child: child,
                    );
                  },
                  itemBuilder: (_, i) {
                    final s = shots[i];
                    final filename = s['filename'] as String? ?? s['file_name'] as String? ?? '';
                    final id = s['id']?.toString() ?? '';
                    final imageUrl = '${baseUrl}/qa/screenshots/file/$filename';
                    return Container(
                      key: ValueKey(id),
                      width: 168,
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _showImagePreview(context, imageUrl, filename),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                width: 160,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, trace) => Container(
                                  width: 160,
                                  height: 120,
                                  color: const Color(0xFF2A2A3E),
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.white38),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () async {
                                final ok = await ExecutionController.to
                                    .deleteScreenshot(id);
                                if (!ok) {
                                  Get.snackbar(
                                      'Error', 'No se pudo eliminar',
                                      backgroundColor:
                                          const Color(0xFFE53935),
                                      colorText: Colors.white);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),

            // ── Register bug button ────────────────────────────────────
            if (_currentStatus == 'failed') ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    side: const BorderSide(color: Color(0xFFE53935)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Get.toNamed(
                    '/bug/form',
                    arguments: {
                      'resultId': widget.result.id,
                      'testCaseTitle': title,
                    },
                  ),
                  icon: const Icon(Icons.bug_report_outlined, size: 18),
                  label: const Text('Registrar Bug', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _statusBtn(String status, String label, Color color) {
    final isActive = _currentStatus == status;
    if (isActive) {
      return FilledButton(
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: () => _setStatus(status),
        child: Text(label),
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      onPressed: () => _setStatus(status),
      child: Text(label),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl, String filename) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white38, size: 64),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
      barrierColor: Colors.black87,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Steps DataTable
// ─────────────────────────────────────────────────────────────────────────────

class _StepsTable extends StatelessWidget {
  final List<dynamic> steps;

  const _StepsTable({required this.steps});

  static const _headerStyle = TextStyle(
    color: Colors.white54,
    fontWeight: FontWeight.bold,
    fontSize: 13,
  );
  static const _cellStyle = TextStyle(color: Colors.white70, fontSize: 13);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(40),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(3),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E).withValues(alpha: 0.5),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text('#', style: _headerStyle),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text('Acción', style: _headerStyle),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text('Datos de prueba', style: _headerStyle),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text('Resultado Esperado', style: _headerStyle),
              ),
            ],
          ),
          // Rows
          ...List.generate(steps.length, (i) {
            final step = steps[i] as Map<String, dynamic>? ?? {};
            return TableRow(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text('${i + 1}', style: _cellStyle),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(step['action'] as String? ?? '', style: _cellStyle),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(step['test_data'] as String? ?? '', style: _cellStyle),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(step['expected_result'] as String? ?? '', style: _cellStyle),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
