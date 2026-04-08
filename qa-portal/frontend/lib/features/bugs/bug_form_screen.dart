import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'bugs_controller.dart';

class BugFormScreen extends StatefulWidget {
  const BugFormScreen({super.key});

  @override
  State<BugFormScreen> createState() => _BugFormScreenState();
}

class _BugFormScreenState extends State<BugFormScreen> {
  late final Map<String, dynamic> args;
  late final String resultId;
  late final String testCaseTitle;

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();

  String _severity = 'medium';
  String? _aiSuggestedSeverity;

  bool _loadingDraft = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    args = Get.arguments as Map<String, dynamic>? ?? {};
    resultId = args['resultId'] as String? ?? '';
    testCaseTitle = args['testCaseTitle'] as String? ?? '';
    _fetchDraft();
  }

  Future<void> _fetchDraft() async {
    setState(() => _loadingDraft = true);
    final draft = await BugsController.to.draftBug(resultId);
    if (draft != null && mounted) {
      setState(() {
        _titleCtrl.text = draft['title'] as String? ?? '';
        _descCtrl.text = draft['description'] as String? ?? '';
        _stepsCtrl.text =
            draft['steps_to_reproduce'] as String? ?? '';
        _aiSuggestedSeverity =
            draft['severity'] as String? ?? 'medium';
        _severity = _aiSuggestedSeverity!;
      });
    }
    if (mounted) setState(() => _loadingDraft = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await BugsController.to.createBug(resultId, {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'steps_to_reproduce': _stepsCtrl.text.trim(),
      'severity': _severity,
    });
    setState(() => _saving = false);
    if (ok) {
      Get.back(result: true);
    } else {
      Get.snackbar('Error', 'No se pudo registrar el bug',
          backgroundColor: const Color(0xFFE53935),
          colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A3E),
        foregroundColor: Colors.white,
        title: const Text('Registrar Bug'),
        actions: [
          if (!_loadingDraft)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar',
                      style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loadingDraft
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  SizedBox(height: 16),
                  Text(
                    'Generando borrador con IA...',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Context chip ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.assignment_outlined,
                              color: Colors.white38, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              testCaseTitle,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── AI severity suggestion ───────────────────────────
                    if (_aiSuggestedSeverity != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: Color(0xFF6C63FF), size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'Severidad sugerida por IA:',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: Text(
                                _severityLabel(_aiSuggestedSeverity!),
                                style: const TextStyle(
                                    color: Color(0xFF6C63FF),
                                    fontSize: 12)),
                            backgroundColor: const Color(0xFF6C63FF)
                                .withValues(alpha: 0.15),
                            side: const BorderSide(
                                color: Color(0xFF6C63FF), width: 0.5),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(
                                () => _severity = _aiSuggestedSeverity!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Title ────────────────────────────────────────────
                    _label('Título *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Ej. El botón X no responde al clic'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'El título es requerido'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Description ──────────────────────────────────────
                    _label('Descripción'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          _inputDecoration('Descripción detallada del bug'),
                    ),
                    const SizedBox(height: 16),

                    // ── Steps to reproduce ───────────────────────────────
                    _label('Pasos para reproducir'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _stepsCtrl,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                          '1. Ir a...\n2. Hacer clic en...\n3. Observar que...'),
                    ),
                    const SizedBox(height: 16),

                    // ── Severity ─────────────────────────────────────────
                    _label('Severidad'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _severity,
                      dropdownColor: const Color(0xFF2A2A3E),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(null),
                      items: const [
                        DropdownMenuItem(
                            value: 'critical',
                            child: Text('Crítico',
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: 'high',
                            child: Text('Alto',
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: 'medium',
                            child: Text('Medio',
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: 'low',
                            child: Text('Bajo',
                                style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (v) =>
                          setState(() => _severity = v ?? _severity),
                    ),
                    const SizedBox(height: 32),

                    // ── Action buttons ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side:
                                  const BorderSide(color: Colors.white24),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed:
                                _saving ? null : () => Get.back(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Text('Registrar Bug', style: TextStyle(color: Colors.white),),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF6C63FF))),
      errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE53935))),
      focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE53935))),
      filled: true,
      fillColor: const Color(0xFF2A2A3E),
    );
  }
}
