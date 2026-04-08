import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/providers/auth_controller.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/models/project.dart';
import 'projects_controller.dart';

class ModuleDetailScreen extends StatefulWidget {
  const ModuleDetailScreen({super.key});

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  late final String moduleId;
  late final String projectId;
  late final String projectName;
  late final String moduleName;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args == null || args['moduleId'] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed('/projects');
      });
      moduleId = '';
      projectId = '';
      projectName = '';
      moduleName = '';
      return;
    }
    moduleId = args['moduleId'] as String;
    projectId = args['projectId'] as String? ?? '';
    projectName = args['projectName'] as String? ?? '';
    moduleName = args['moduleName'] as String? ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProjectsController.to.loadTestCases(moduleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthController.to.user.value?.isAdmin == true;

    return AppShell(
      title: moduleName,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    // Breadcrumb
                    GestureDetector(
                      onTap: () => Get.offAllNamed('/projects'),
                      child: const Text(
                        'Proyectos',
                        style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                    const Text(
                      ' > ',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Text(
                        projectName,
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                    const Text(
                      ' > ',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                    Text(
                      moduleName,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const Spacer(),
                    // Generar con IA
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6C63FF),
                        side: const BorderSide(color: Color(0xFF6C63FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Generar con IA'),
                      onPressed: () => _showAIDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white12, height: 1),

              // ── Test case count ────────────────────────────────────────
              Obx(() {
                final count = ProjectsController.to.testCases.length;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(
                    '$count ${count == 1 ? 'caso de prueba' : 'casos de prueba'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                );
              }),
              const SizedBox(height: 8),

              // ── Test case list ─────────────────────────────────────────
              Expanded(
                child: Obx(() {
                  final ctrl = ProjectsController.to;

                  if (ctrl.loading.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                    );
                  }

                  if (ctrl.testCases.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.checklist_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No hay casos de prueba aún',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
                    itemCount: ctrl.testCases.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      final item = ctrl.testCases.removeAt(oldIndex);
                      ctrl.testCases.insert(newIndex, item);
                      ctrl.reorderTestCases(moduleId);
                    },
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 4,
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final tc = ctrl.testCases[index];
                      return _TestCaseCard(
                        key: ValueKey(tc.id),
                        testCase: tc,
                        moduleId: moduleId,
                        isAdmin: isAdmin,
                      );
                    },
                  );
                }),
              ),
            ],
          ),

          // ── FAB ────────────────────────────────────────────────────────
          Positioned(
            bottom: 24,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              tooltip: 'Nuevo caso de prueba',
              onPressed: () => Get.toNamed(
                '/test-case/form',
                arguments: {'moduleId': moduleId},
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _showAIDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AIGenerateDialog(moduleId: moduleId),
    );
  }
}

// ─── Test Case Card (ExpansionTile) ───────────────────────────────────────────

class _TestCaseCard extends StatelessWidget {
  final TestCase testCase;
  final String moduleId;
  final bool isAdmin;

  const _TestCaseCard({
    required this.testCase,
    required this.moduleId,
    required this.isAdmin,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 40, 16),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4),
              _StatusBadge(status: testCase.status),
            ],
          ),
          title: Text(
            testCase.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                color: const Color(0xFF2A2A3E),
                icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                onSelected: (value) async {
                  if (value == 'edit') {
                    Get.toNamed(
                      '/test-case/form',
                      arguments: {
                        'moduleId': moduleId,
                        'testCase': testCase.toJson(),
                      },
                    );
                  } else if (value == 'duplicate') {
                    await ProjectsController.to.duplicateTestCase(testCase.id);
                  } else if (value == 'delete') {
                    _confirmDelete(context);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Editar', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy_outlined, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Duplicar', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Eliminar',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 15),
            ],
          ),
          children: [
            if (testCase.preconditions != null &&
                testCase.preconditions!.isNotEmpty) ...[
              _DetailRow(label: 'Precondiciones', value: testCase.preconditions!),
              const SizedBox(height: 8),
            ],
            if (testCase.postconditions != null &&
                testCase.postconditions!.isNotEmpty) ...[
              _DetailRow(label: 'Postcondiciones', value: testCase.postconditions!),
              const SizedBox(height: 12),
            ],
            if (testCase.steps.isNotEmpty) ...[
              const Text(
                'Pasos',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              _StepsTable(steps: testCase.steps),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text(
          'Eliminar caso de prueba',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Eliminar "${testCase.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await ProjectsController.to.deleteTestCase(testCase.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _StepsTable extends StatelessWidget {
  final List<TestStep> steps;
  const _StepsTable({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(36),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(3),
      },
      border: TableBorder.all(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF1E1E2E)),
          children: [
            _TableHeader('#'),
            _TableHeader('Acción'),
            _TableHeader('Datos'),
            _TableHeader('Resultado Esperado'),
          ],
        ),
        // Rows
        ...steps.map(
          (step) => TableRow(
            children: [
              _TableCell(step.order.toString(), center: true),
              _TableCell(step.action),
              _TableCell(step.testData ?? '—'),
              _TableCell(step.expectedResult),
            ],
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool center;
  const _TableCell(this.text, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'active' || status.toLowerCase() == 'activo';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 0.8,
        ),
      ),
      child: Text(
        isActive ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: isActive ? Colors.greenAccent : Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── AI Generate Dialog ───────────────────────────────────────────────────────

class _AIGenerateDialog extends StatefulWidget {
  final String moduleId;
  const _AIGenerateDialog({required this.moduleId});

  @override
  State<_AIGenerateDialog> createState() => _AIGenerateDialogState();
}

class _AIGenerateDialogState extends State<_AIGenerateDialog> {
  final _descCtrl = TextEditingController();
  List<Map<String, dynamic>>? _testCases;
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_descCtrl.text.trim().isEmpty) return;
    setState(() => _testCases = null);

    final result = await ProjectsController.to.generateWithAI(
      widget.moduleId,
      _descCtrl.text.trim(),
    );

    if (mounted && result != null) {
      final raw = result['test_cases'] as List<dynamic>? ?? [];
      setState(() {
        _testCases = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    }
  }

  void _removeCase(int index) {
    setState(() => _testCases!.removeAt(index));
  }

  Future<void> _saveAll() async {
    if (_testCases == null || _testCases!.isEmpty) return;
    setState(() => _saving = true);

    bool allOk = true;
    for (final tc in _testCases!) {
      final ok = await ProjectsController.to.createTestCase(
        widget.moduleId, tc,
      );
      if (!ok) allOk = false;
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      if (!allOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Algunos casos no pudieron guardarse')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A3E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 20),
                  SizedBox(width: 8),
                  Text('Generar casos con IA',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),

              // Input
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Describe la funcionalidad a probar...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E1E2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Results
              Expanded(child: _buildResults()),

              // Actions
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  if (_testCases == null)
                    Obx(() {
                      final loading = ProjectsController.to.aiLoading.value;
                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Generar'),
                        onPressed: loading ? null : _generate,
                      );
                    })
                  else if (_testCases!.isNotEmpty)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _saving
                          ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_alt, size: 16),
                      label: Text('Guardar ${_testCases!.length} caso(s)'),
                      onPressed: _saving ? null : _saveAll,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    return Obx(() {
      final loading = ProjectsController.to.aiLoading.value;
      final aiError = ProjectsController.to.aiError.value;

      if (loading) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
      }
      if (aiError.isNotEmpty) {
        return Center(child: Text(aiError, style: const TextStyle(color: Colors.redAccent)));
      }
      if (_testCases == null) {
        return const Center(
          child: Text('Describe la funcionalidad y presiona Generar.',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        );
      }
      if (_testCases!.isEmpty) {
        return const Center(
          child: Text('Eliminaste todos los casos. Genera de nuevo o cancela.',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        );
      }

      return ListView.builder(
        itemCount: _testCases!.length,
        itemBuilder: (_, i) {
          final tc = _testCases![i];
          final steps = tc['steps'] as List<dynamic>? ?? [];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                title: Text(tc['title']?.toString() ?? 'Sin título',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  tooltip: 'Eliminar este caso',
                  onPressed: () => _removeCase(i),
                ),
                children: [
                  if (tc['preconditions'] != null && tc['preconditions'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Precondiciones: ',
                              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                          Expanded(child: Text(tc['preconditions'].toString(),
                              style: const TextStyle(color: Colors.white70, fontSize: 11))),
                        ],
                      ),
                    ),
                  if (steps.isNotEmpty)
                    Table(
                      columnWidths: const {
                        0: FixedColumnWidth(30),
                        1: FlexColumnWidth(3),
                        2: FlexColumnWidth(2),
                        3: FlexColumnWidth(3),
                      },
                      border: TableBorder.all(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFF2A2A3E)),
                          children: [
                            _AITableCell('#', header: true),
                            _AITableCell('Acción', header: true),
                            _AITableCell('Datos', header: true),
                            _AITableCell('Resultado Esperado', header: true),
                          ],
                        ),
                        ...steps.asMap().entries.map((e) {
                          final s = e.value as Map<String, dynamic>;
                          return TableRow(children: [
                            _AITableCell('${e.key + 1}'),
                            _AITableCell(s['action']?.toString() ?? ''),
                            _AITableCell(s['test_data']?.toString() ?? '—'),
                            _AITableCell(s['expected_result']?.toString() ?? ''),
                          ]);
                        }),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

class _AITableCell extends StatelessWidget {
  final String text;
  final bool header;
  const _AITableCell(this.text, {this.header = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Text(text,
          style: TextStyle(
            color: header ? Colors.white54 : Colors.white70,
            fontSize: 11,
            fontWeight: header ? FontWeight.w700 : FontWeight.normal,
          )),
    );
  }
}
