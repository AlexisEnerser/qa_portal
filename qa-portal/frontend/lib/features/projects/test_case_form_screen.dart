import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'projects_controller.dart';

class TestCaseFormScreen extends StatefulWidget {
  const TestCaseFormScreen({super.key});

  @override
  State<TestCaseFormScreen> createState() => _TestCaseFormScreenState();
}

class _TestCaseFormScreenState extends State<TestCaseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Args
  late final String moduleId;
  late final Map<String, dynamic>? existingTestCase;
  bool get isEditing => existingTestCase != null;

  // Controllers
  late final TextEditingController _titleCtrl;
  late final TextEditingController _preconditionsCtrl;
  late final TextEditingController _postconditionsCtrl;

  // Steps
  final List<_StepRow> _steps = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args == null || args['moduleId'] == null) {
      moduleId = '';
      existingTestCase = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed('/projects');
      });
      return;
    }
    moduleId = args['moduleId'] as String;
    existingTestCase = args['testCase'] as Map<String, dynamic>?;

    _titleCtrl = TextEditingController(
      text: existingTestCase?['title'] as String? ?? '',
    );
    _preconditionsCtrl = TextEditingController(
      text: existingTestCase?['preconditions'] as String? ?? '',
    );
    _postconditionsCtrl = TextEditingController(
      text: existingTestCase?['postconditions'] as String? ?? '',
    );

    // Pre-populate steps if editing
    if (isEditing) {
      final rawSteps =
          existingTestCase!['steps'] as List<dynamic>? ?? [];
      for (final s in rawSteps) {
        final step = s as Map<String, dynamic>;
        _steps.add(
          _StepRow(
            actionCtrl: TextEditingController(
                text: step['action'] as String? ?? ''),
            testDataCtrl: TextEditingController(
                text: step['test_data'] as String? ?? ''),
            expectedResultCtrl: TextEditingController(
                text: step['expected_result'] as String? ?? ''),
          ),
        );
      }
    }

    if (_steps.isEmpty) _addStep();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _preconditionsCtrl.dispose();
    _postconditionsCtrl.dispose();
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  void _addStep() {
    setState(() {
      _steps.add(_StepRow(
        actionCtrl: TextEditingController(),
        testDataCtrl: TextEditingController(),
        expectedResultCtrl: TextEditingController(),
      ));
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps[index].dispose();
      _steps.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final stepsList = _steps.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      return {
        'order': i + 1,
        'action': s.actionCtrl.text.trim(),
        'test_data': s.testDataCtrl.text.trim(),
        'expected_result': s.expectedResultCtrl.text.trim(),
      };
    }).toList();

    final body = {
      'title': _titleCtrl.text.trim(),
      'preconditions': _preconditionsCtrl.text.trim(),
      'postconditions': _postconditionsCtrl.text.trim(),
      'steps': stepsList,
    };

    bool success;
    if (!isEditing) {
      success = await ProjectsController.to.createTestCase(moduleId, body);
    } else {
      final testCaseId = existingTestCase!['id'] as String;
      success = await ProjectsController.to.updateTestCase(testCaseId, body);
    }

    if (mounted) {
      setState(() => _saving = false);
      if (success) {
        Get.back();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar el caso de prueba')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A3E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditing ? 'Editar caso de prueba' : 'Nuevo caso de prueba',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Get.back(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _saving
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Guardar'),
                    onPressed: _save,
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Title ────────────────────────────────────────────────────
            _SectionLabel('Información General'),
            const SizedBox(height: 12),
            _DarkTextFormField(
              controller: _titleCtrl,
              label: 'Título *',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El título es requerido' : null,
            ),
            const SizedBox(height: 16),

            // ── Preconditions ─────────────────────────────────────────────
            _DarkTextFormField(
              controller: _preconditionsCtrl,
              label: 'Precondiciones',
              maxLines: 3,
              hint: 'Ej: El usuario debe estar registrado en el sistema...',
            ),
            const SizedBox(height: 16),

            // ── Postconditions ────────────────────────────────────────────
            _DarkTextFormField(
              controller: _postconditionsCtrl,
              label: 'Postcondiciones',
              maxLines: 3,
              hint: 'Ej: El sistema registra el evento en el log...',
            ),
            const SizedBox(height: 28),

            // ── Steps ─────────────────────────────────────────────────────
            Row(
              children: [
                _SectionLabel('Pasos'),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6C63FF),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar paso'),
                  onPressed: _addStep,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_steps.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No hay pasos. Agrega al menos uno.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _steps.removeAt(oldIndex);
                    _steps.insert(newIndex, item);
                  });
                },
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    elevation: 4,
                    child: child,
                  );
                },
                itemBuilder: (_, index) {
                  final step = _steps[index];
                  return _StepCard(
                    key: ValueKey('step_${step.hashCode}'),
                    index: index,
                    step: step,
                    onRemove: _steps.length > 1
                        ? () => _removeStep(index)
                        : null,
                  );
                },
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Step data holder ─────────────────────────────────────────────────────────

class _StepRow {
  final TextEditingController actionCtrl;
  final TextEditingController testDataCtrl;
  final TextEditingController expectedResultCtrl;

  _StepRow({
    required this.actionCtrl,
    required this.testDataCtrl,
    required this.expectedResultCtrl,
  });

  void dispose() {
    actionCtrl.dispose();
    testDataCtrl.dispose();
    expectedResultCtrl.dispose();
  }
}

// ─── Step Card ────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int index;
  final _StepRow step;
  final VoidCallback? onRemove;

  const _StepCard({
    required this.index,
    required this.step,
    this.onRemove,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(
        left: 16, 
        right: 35,
        top: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Paso',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.redAccent, size: 20),
                  tooltip: 'Eliminar paso',
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _DarkTextFormField(
            controller: step.actionCtrl,
            label: 'Acción *',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'La acción es requerida' : null,
          ),
          const SizedBox(height: 10),
          _DarkTextFormField(
            controller: step.testDataCtrl,
            label: 'Datos de prueba (opcional)',
            hint: 'Ej: usuario@ejemplo.com / Contraseña123',
          ),
          const SizedBox(height: 10),
          _DarkTextFormField(
            controller: step.expectedResultCtrl,
            label: 'Resultado esperado *',
            maxLines: 2,
            validator: (v) =>
                (v == null || v.trim().isEmpty)
                    ? 'El resultado esperado es requerido'
                    : null,
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ─── Dark text form field ─────────────────────────────────────────────────────

class _DarkTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final String? hint;
  final String? Function(String?)? validator;

  const _DarkTextFormField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6C63FF)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
      ),
    );
  }
}
